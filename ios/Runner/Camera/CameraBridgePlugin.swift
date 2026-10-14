import Flutter
import UIKit
import AVFoundation

/// Plugin Flutter gérant le pont de communication natif pour DaWishCam.
///
/// Implémente le contrat d'interface défini dans `contracts/camera-channel.md`.
public class CameraBridgePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let registrar: FlutterPluginRegistrar
  private var eventSink: FlutterEventSink?
  private var sessionController: CameraSessionController?
  private var rawCaptureService: RawPhotoCaptureService?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "com.dawishcam/camera", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "com.dawishcam/camera_events", binaryMessenger: registrar.messenger())
    let instance = CameraBridgePlugin(registrar: registrar)
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initializeCamera":
      handleInitializeCamera(result: result)

    case "setManualIso":
      guard let args = call.arguments as? [String: Any],
            let iso = args["iso"] as? NSNumber else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "ISO value required", details: nil))
        return
      }
      guard let sessionController = sessionController else {
        result(FlutterError(code: "CAMERA_NOT_INITIALIZED", message: "Camera session not initialized", details: nil))
        return
      }
      sessionController.setManualIso(Float(truncating: iso), completion: result)

    case "setManualExposure":
      guard let args = call.arguments as? [String: Any],
            let durationSeconds = args["durationSeconds"] as? NSNumber else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Duration seconds required", details: nil))
        return
      }
      guard let sessionController = sessionController else {
        result(FlutterError(code: "CAMERA_NOT_INITIALIZED", message: "Camera session not initialized", details: nil))
        return
      }
      sessionController.setManualExposure(Double(truncating: durationSeconds), completion: result)

    case "setManualFocus":
      guard let args = call.arguments as? [String: Any],
            let lensPosition = args["lensPosition"] as? NSNumber else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Lens position required", details: nil))
        return
      }
      guard let sessionController = sessionController else {
        result(FlutterError(code: "CAMERA_NOT_INITIALIZED", message: "Camera session not initialized", details: nil))
        return
      }
      sessionController.setManualFocus(Float(truncating: lensPosition), completion: result)

    case "setFlashMode":
      guard let args = call.arguments as? [String: Any],
            let enabled = args["enabled"] as? Bool else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Flash mode boolean required", details: nil))
        return
      }
      guard let captureService = rawCaptureService, captureService.isFlashSupported else {
        result(FlutterError(code: "FLASH_UNAVAILABLE", message: "Flash mode .on is not supported by device or photo output", details: nil))
        return
      }
      _ = captureService.setFlashEnabled(enabled)
      result(nil)

    case "captureBayerRaw":
      handleCaptureBayerRaw(result: result)

    case "pausePreview":
      sessionController?.pausePreview()
      result(nil)

    case "resumePreview":
      sessionController?.resumePreview()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleInitializeCamera(result: @escaping FlutterResult) {
    let controller = CameraSessionController(textureRegistry: registrar.textures())
    self.sessionController = controller
    let captureService = RawPhotoCaptureService()
    self.rawCaptureService = captureService

    controller.initializeSession { [weak self] initResult in
      switch initResult {
      case .success(let info):
        // Lier la sortie photo RAW à la session de capture
        if let photoOutput = controller.photoOutput {
          captureService.configure(photoOutput: photoOutput, device: controller.cameraDevice)
        }

        var response: [String: Any] = [
          "textureId": info.textureId,
          "isBayerRawSupported": captureService.isBayerRawSupported,
          "hasFlash": controller.hasFlash,
          "isFlashSupported": captureService.isFlashSupported,
          "isFocusLockSupported": info.isFocusLockSupported
        ]

        if let rawFormat = captureService.detectedRawPixelFormat {
          response["detectedRawPixelFormat"] = rawFormat
        }
        if let minIso = info.minIso {
          response["minIso"] = minIso
        }
        if let maxIso = info.maxIso {
          response["maxIso"] = maxIso
        }
        if let minExposure = info.minExposureDurationSeconds {
          response["minExposureDurationSeconds"] = minExposure
        }
        if let maxExposure = info.maxExposureDurationSeconds {
          response["maxExposureDurationSeconds"] = maxExposure
        }

        result(response)

      case .failure(let error):
        result(FlutterError(code: "INITIALIZATION_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func handleCaptureBayerRaw(result: @escaping FlutterResult) {
    guard let captureService = rawCaptureService else {
      result(FlutterError(code: "CAMERA_NOT_INITIALIZED", message: "Camera session not initialized", details: nil))
      return
    }

    guard captureService.isBayerRawSupported else {
      result(FlutterError(
        code: "RAW_UNAVAILABLE",
        message: "Bayer RAW capture is not supported on this device/configuration",
        details: nil
      ))
      return
    }

    sendEvent(["event": "captureStateChanged", "state": "capturing"])

    captureService.captureBayerRaw { [weak self] captureResult in
      switch captureResult {
      case .success(let captureInfo):
        self?.sendEvent(["event": "captureStateChanged", "state": "completed"])
        var payload: [String: Any] = [
          "captureId": captureInfo.captureId,
          "rawFilePath": captureInfo.rawFilePath,
          "rawPixelFormat": captureInfo.rawPixelFormat,
          "byteCount": captureInfo.byteCount,
          "status": "completed"
        ]
        if let previewPath = captureInfo.previewFilePath {
          payload["previewFilePath"] = previewPath
        }
        if let w = captureInfo.previewWidth {
          payload["previewWidth"] = w
        }
        if let h = captureInfo.previewHeight {
          payload["previewHeight"] = h
        }
        result(payload)

      case .failure(let error):
        self?.sendEvent([
          "event": "captureStateChanged",
          "state": "failed",
          "errorCode": "CAPTURE_ERROR",
          "message": error.localizedDescription
        ])
        result(FlutterError(code: "CAPTURE_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }

  private func sendEvent(_ data: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(data)
    }
  }

  // MARK: - FlutterStreamHandler
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
