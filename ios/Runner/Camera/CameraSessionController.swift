import Flutter
import UIKit
import AVFoundation

/// Informations découvertes dynamiquement sur la session et l'appareil.
public struct SessionInitInfo {
  public let textureId: Int64
  public let hasFlash: Bool
  public let isFocusLockSupported: Bool
  public let minIso: Double?
  public let maxIso: Double?
  public let minExposureDurationSeconds: Double?
  public let maxExposureDurationSeconds: Double?
}

/// Contrôleur de session caméra natif sous AVFoundation.
///
/// Gère la capture vidéo, la régulation de la présentation du preview à 24 FPS
/// vers FlutterTexture, et la découverte dynamique des capacités réelles de l'appareil.
public class CameraSessionController: NSObject, FlutterTexture, AVCaptureVideoDataOutputSampleBufferDelegate {
  private let textureRegistry: FlutterTextureRegistry
  private var textureId: Int64 = 0
  private let captureSession = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "com.dawishcam.sessionQueue")
  private let videoOutputQueue = DispatchQueue(label: "com.dawishcam.videoOutputQueue")

  public private(set) var cameraDevice: AVCaptureDevice?
  public private(set) var photoOutput: AVCapturePhotoOutput?
  private var videoDataOutput: AVCaptureVideoDataOutput?

  // Gestion des buffers pour FlutterTexture
  private var latestPixelBuffer: CVPixelBuffer?
  private let pixelBufferLock = NSLock()

  // Régulation temporelle de la présentation à 24 FPS
  private var lastFrameTime: CMTime = .invalid
  private let targetFrameDurationSeconds: Double = 1.0 / 24.0

  public var hasFlash: Bool {
    return cameraDevice?.hasFlash ?? false
  }

  public init(textureRegistry: FlutterTextureRegistry) {
    self.textureRegistry = textureRegistry
    super.init()
  }

  /// Initialise la session caméra, découvre les capacités et enregistre la texture Flutter.
  public func initializeSession(completion: @escaping (Result<SessionInitInfo, Error>) -> Void) {
    sessionQueue.async { [weak self] in
      guard let self = self else { return }

      do {
        // Enregistrer la texture auprès du moteur Flutter
        self.textureId = self.textureRegistry.register(self)

        // Découverte du capteur grand angle arrière par défaut
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
          throw NSError(domain: "DaWishCam", code: 1, userInfo: [NSLocalizedDescriptionKey: "No back camera available on this device"])
        }
        self.cameraDevice = device

        self.captureSession.beginConfiguration()
        self.captureSession.sessionPreset = .photo

        // Ajout de l'entrée capteur
        let input = try AVCaptureDeviceInput(device: device)
        if self.captureSession.canAddInput(input) {
          self.captureSession.addInput(input)
        } else {
          throw NSError(domain: "DaWishCam", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot add camera input to session"])
        }

        // Configuration de la sortie vidéo pour le preview
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
          kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)

        if self.captureSession.canAddOutput(videoOutput) {
          self.captureSession.addOutput(videoOutput)
          self.videoDataOutput = videoOutput
        } else {
          throw NSError(domain: "DaWishCam", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot add video data output to session"])
        }

        // Configuration de la sortie photo pour la capture RAW
        let photoOut = AVCapturePhotoOutput()
        if self.captureSession.canAddOutput(photoOut) {
          self.captureSession.addOutput(photoOut)
          self.photoOutput = photoOut
        }

        self.captureSession.commitConfiguration()
        self.captureSession.startRunning()

        // Découverte dynamique des plages réelles sans présomption
        let format = device.activeFormat
        let minIso = Double(format.minISO)
        let maxIso = Double(format.maxISO)
        let minDuration = Double(format.minExposureDuration.seconds)
        let maxDuration = Double(format.maxExposureDuration.seconds)
        let isFocusLockSupported = device.isLockingFocusWithCustomLensPositionSupported

        let info = SessionInitInfo(
          textureId: self.textureId,
          hasFlash: device.hasFlash,
          isFocusLockSupported: isFocusLockSupported,
          minIso: minIso,
          maxIso: maxIso,
          minExposureDurationSeconds: minDuration,
          maxExposureDurationSeconds: maxDuration
        )

        DispatchQueue.main.async {
          completion(.success(info))
        }
      } catch {
        DispatchQueue.main.async {
          completion(.failure(error))
        }
      }
    }
  }

  // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
  public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    let currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

    // Régulation de la présentation du preview à 24 FPS
    if lastFrameTime.isValid {
      let deltaSeconds = CMTimeGetSeconds(CMTimeSubtract(currentTime, lastFrameTime))
      // Si la trame arrive trop tôt par rapport à la cadence de présentation à 24 FPS, on la filtre
      if deltaSeconds < (targetFrameDurationSeconds * 0.95) {
        return
      }
    }

    lastFrameTime = currentTime

    pixelBufferLock.lock()
    latestPixelBuffer = pixelBuffer
    pixelBufferLock.unlock()

    textureRegistry.textureFrameAvailable(textureId)
  }

  // MARK: - FlutterTexture
  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    pixelBufferLock.lock()
    defer { pixelBufferLock.unlock() }

    guard let buffer = latestPixelBuffer else { return nil }
    return Unmanaged.passRetained(buffer)
  }

  // MARK: - Réglages manuels & Cycle de vie
  public func setManualIso(_ iso: Float, completion: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self = self, let device = self.cameraDevice else {
        completion(FlutterError(code: "NO_CAMERA", message: "Device unavailable", details: nil))
        return
      }
      guard device.isExposureModeSupported(.custom) else {
        DispatchQueue.main.async {
          completion(FlutterError(
            code: "EXPOSURE_CUSTOM_UNSUPPORTED",
            message: "Custom exposure mode is not supported on this device/format",
            details: nil
          ))
        }
        return
      }
      do {
        try device.lockForConfiguration()
        let currentDuration = device.exposureDuration
        let clampedIso = min(max(iso, device.activeFormat.minISO), device.activeFormat.maxISO)
        device.setExposureModeCustom(duration: currentDuration, iso: clampedIso) { _ in }
        device.unlockForConfiguration()
        DispatchQueue.main.async { completion(nil) }
      } catch {
        DispatchQueue.main.async {
          completion(FlutterError(code: "CONFIG_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  public func setManualExposure(_ durationSeconds: Double, completion: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self = self, let device = self.cameraDevice else {
        completion(FlutterError(code: "NO_CAMERA", message: "Device unavailable", details: nil))
        return
      }
      guard device.isExposureModeSupported(.custom) else {
        DispatchQueue.main.async {
          completion(FlutterError(
            code: "EXPOSURE_CUSTOM_UNSUPPORTED",
            message: "Custom exposure mode is not supported on this device/format",
            details: nil
          ))
        }
        return
      }
      do {
        try device.lockForConfiguration()
        let minDuration = device.activeFormat.minExposureDuration.seconds
        let maxDuration = device.activeFormat.maxExposureDuration.seconds
        let clampedSeconds = min(max(durationSeconds, minDuration), maxDuration)
        let cmDuration = CMTime(seconds: clampedSeconds, preferredTimescale: 1000000)
        let currentIso = device.iso
        device.setExposureModeCustom(duration: cmDuration, iso: currentIso) { _ in }
        device.unlockForConfiguration()
        DispatchQueue.main.async { completion(nil) }
      } catch {
        DispatchQueue.main.async {
          completion(FlutterError(code: "CONFIG_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  public func setManualFocus(_ lensPosition: Float, completion: @escaping FlutterResult) {
    sessionQueue.async { [weak self] in
      guard let self = self, let device = self.cameraDevice else {
        completion(FlutterError(code: "NO_CAMERA", message: "Device unavailable", details: nil))
        return
      }

      guard device.isLockingFocusWithCustomLensPositionSupported else {
        DispatchQueue.main.async {
          completion(FlutterError(
            code: "FOCUS_LOCK_UNSUPPORTED",
            message: "Custom lens position focus locking is not supported on this device/format",
            details: nil
          ))
        }
        return
      }

      do {
        try device.lockForConfiguration()
        let clampedPos = min(max(lensPosition, 0.0), 1.0)
        device.setFocusModeLocked(lensPosition: clampedPos) { _ in }
        device.unlockForConfiguration()
        DispatchQueue.main.async { completion(nil) }
      } catch {
        DispatchQueue.main.async {
          completion(FlutterError(code: "CONFIG_ERROR", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  public func pausePreview() {
    sessionQueue.async { [weak self] in
      if self?.captureSession.isRunning == true {
        self?.captureSession.stopRunning()
      }
    }
  }

  public func resumePreview() {
    sessionQueue.async { [weak self] in
      if self?.captureSession.isRunning == false {
        self?.captureSession.startRunning()
      }
    }
  }

  deinit {
    if textureId != 0 {
      textureRegistry.unregisterTexture(textureId)
    }
  }
}
