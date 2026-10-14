import Foundation
import AVFoundation
import CoreVideo
import ImageIO

public struct RawCaptureResultInfo {
  public let captureId: String
  public let rawFilePath: String
  public let previewFilePath: String?
  public let rawPixelFormat: Int
  public let byteCount: Int
  public let previewWidth: Int?
  public let previewHeight: Int?
}

/// Service de capture photo Bayer RAW sous AVFoundation.
///
/// Implémente la vérification empirique des formats Bayer RAW, la persistance
/// exclusive en RAW sans génération de JPEG/HEIF, et la gestion stricte du flash.
public class RawPhotoCaptureService: NSObject, AVCapturePhotoCaptureDelegate {
  public private(set) weak var photoOutput: AVCapturePhotoOutput?
  private weak var cameraDevice: AVCaptureDevice?
  private let demosaicer = CpuBilinearDemosaicer()

  /// Active ou désactive la génération de l'aperçu RGB dématricé pour une capture RAW.
  ///
  /// Maintenu à `false` tant que le cadrage des bits Bayer 14/16 bits (justification gauche ou
  /// droite dans `CpuBilinearDemosaicer.demosaicBayerToRGB`) n'a pas été validé par une capture
  /// réelle sur iPhone 14 physique (voir rapport d'audit : ce point n'est confirmé ni par la
  /// documentation Apple, ni par les forums développeurs consultés). Le code de dématriçage est
  /// conservé intact pour permettre cette validation ultérieure ; il n'est simplement pas invoqué
  /// dans le chemin d'exécution normal tant que ce drapeau reste à `false`. Cette désactivation
  /// n'affecte en rien la persistance du fichier RAW (DNG), qui a toujours lieu indépendamment.
  private let isRgbPreviewGenerationValidated = false

  public private(set) var isBayerRawSupported: Bool = false
  public private(set) var detectedRawPixelFormat: UInt32?
  private var flashEnabled: Bool = false

  private var activeCompletion: ((Result<RawCaptureResultInfo, Error>) -> Void)?

  public override init() {
    super.init()
  }

  /// Configure la sortie photo et découvre expérimentalement les formats Bayer RAW disponibles.
  public func configure(photoOutput: AVCapturePhotoOutput, device: AVCaptureDevice?) {
    self.photoOutput = photoOutput
    self.cameraDevice = device

    // Découverte empirique des formats Bayer RAW supportés
    let rawFormats = photoOutput.availableRawPhotoPixelFormatTypes
    var foundFormat: UInt32?

    for format in rawFormats {
      let formatInt = format.uint32Value
      if AVCapturePhotoOutput.isBayerRAWPixelFormat(formatInt) {
        foundFormat = formatInt
        break
      }
    }

    if let format = foundFormat {
      self.isBayerRawSupported = true
      self.detectedRawPixelFormat = format
    } else {
      self.isBayerRawSupported = false
      self.detectedRawPixelFormat = nil
    }
  }

  /// Indique si le flash est réellement supporté par l'appareil ET par la sortie photo RAW.
  public var isFlashSupported: Bool {
    guard let device = cameraDevice, device.hasFlash,
          let output = photoOutput else {
      return false
    }
    return output.supportedFlashModes.contains(.on)
  }

  /// Règle le mode flash (actif uniquement lors du déclenchement si supporté).
  public func setFlashEnabled(_ enabled: Bool) -> Bool {
    guard isFlashSupported else {
      self.flashEnabled = false
      return false
    }
    self.flashEnabled = enabled
    return true
  }

  /// Déclenche la capture d'une photo Bayer RAW.
  public func captureBayerRaw(completion: @escaping (Result<RawCaptureResultInfo, Error>) -> Void) {
    guard isBayerRawSupported, let rawFormat = detectedRawPixelFormat, let output = photoOutput else {
      completion(.failure(NSError(
        domain: "DaWishCam",
        code: 10,
        userInfo: [NSLocalizedDescriptionKey: "Bayer RAW capture is not supported on this device/configuration"]
      )))
      return
    }

    self.activeCompletion = completion

    // Configuration des réglages de capture : RAW pur, aucun format traité (pas de JPEG/HEIF).
    // Label vérifié auprès de la documentation Apple (init(rawPixelFormatType:)) : l'initialiseur
    // dédié à la capture RAW seule, sans paramètre processedFormat, est celui recommandé par Apple
    // pour exclure explicitement tout format compressé/traité compagnon.
    let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat)

    // Configuration du flash : vérification stricte des capacités effectives
    if isFlashSupported && flashEnabled {
      photoSettings.flashMode = .on
    } else {
      photoSettings.flashMode = .off
    }

    // Le mode torch ne doit jamais être utilisé
    if let device = cameraDevice, device.hasTorch && device.torchMode != .off {
      if (try? device.lockForConfiguration()) != nil {
        device.torchMode = .off
        device.unlockForConfiguration()
      }
    }

    output.capturePhoto(with: photoSettings, delegate: self)
  }

  // MARK: - AVCapturePhotoCaptureDelegate
  public func photoOutput(
    _ output: AVCapturePhotoOutput,
    didFinishProcessingPhoto photo: AVCapturePhoto,
    error: Error?
  ) {
    if let error = error {
      activeCompletion?(.failure(error))
      activeCompletion = nil
      return
    }

    guard photo.isRawPhoto, let rawData = photo.fileDataRepresentation() else {
      let err = NSError(
        domain: "DaWishCam",
        code: 11,
        userInfo: [NSLocalizedDescriptionKey: "No raw photo representation available"]
      )
      activeCompletion?(.failure(err))
      activeCompletion = nil
      return
    }

    let captureId = "raw_\(Int(Date().timeIntervalSince1970))"
    let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    // Extension vérifiée : AVCapturePhoto.fileDataRepresentation() pour une capture RAW sur iOS
    // produit un conteneur DNG lorsque rawFileType n'est pas spécifié (choix automatique par
    // AVCapturePhotoOutput). Le fichier persisté est donc un DNG valide, nommé en conséquence.
    let rawFileUrl = documentsDir.appendingPathComponent("\(captureId).dng")

    do {
      // 1. Persister le buffer Bayer RAW (conteneur DNG) dans le stockage de l'application, sans JPEG.
      //    Toute erreur ici est remontée via le catch ci-dessous (échec de la capture entière).
      try rawData.write(to: rawFileUrl)

      // 2. Tentative de dématriçage pour l'aperçu RGB — uniquement à partir du CVPixelBuffer RAW
      //    fourni par AVFoundation (photo.pixelBuffer), jamais à partir des octets du conteneur DNG
      //    (fileDataRepresentation), qui ne sont pas un buffer de pixels plat et ne doivent jamais
      //    être réinterprétés comme tel.
      var previewFileUrl: URL? = nil
      var previewWidth: Int? = nil
      var previewHeight: Int? = nil

      if isRgbPreviewGenerationValidated {
        // Chemin de dématriçage Bayer → RGB, conservé intact pour validation ultérieure sur
        // iPhone 14 physique (voir `isRgbPreviewGenerationValidated` ci-dessus). Non exécuté
        // dans le chemin normal tant que ce drapeau reste à `false`.
        if let pixelBuffer = photo.pixelBuffer {
          let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

          if AVCapturePhotoOutput.isBayerRAWPixelFormat(pixelFormat),
             let layout = determineBayerLayout(fourCharCode: pixelFormat, metadata: photo.metadata),
             let bytesPerPixel = bayerSampleByteSize(fourCharCode: pixelFormat) {

            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

            if let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) {
              let width = CVPixelBufferGetWidth(pixelBuffer)
              let height = CVPixelBufferGetHeight(pixelBuffer)
              // Stride réel du buffer, tel que rapporté par CoreVideo pour cette capture précise
              // (jamais recalculé à partir de la largeur, pour respecter un éventuel alignement/padding).
              let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

              if let rgbData = demosaicer.demosaicBayerToRGB(
                pixelBytes: baseAddress,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                bytesPerPixel: bytesPerPixel,
                layout: layout
              ) {
                let rgbUrl = documentsDir.appendingPathComponent("\(captureId)_preview.rgb")
                do {
                  try rgbData.write(to: rgbUrl)
                  previewFileUrl = rgbUrl
                  previewWidth = width
                  previewHeight = height
                } catch {
                  // Échec d'écriture de l'aperçu : ne jamais déclarer un fichier d'aperçu qui n'a pas
                  // été réellement persisté. La capture RAW reste valide et est retournée sans aperçu.
                  print("DaWishCam: échec d'écriture de l'aperçu RGB (\(error)). Capture RAW conservée sans aperçu.")
                }
              }
            }
          } else {
            // Format/motif Bayer non confirmé pour ce CVPixelBuffer : pas de dématriçage par
            // hypothèse. La capture RAW reste valide et est retournée sans aperçu.
            print("DaWishCam: format ou motif Bayer non identifiable pour ce CVPixelBuffer. Aperçu non généré, fichier RAW conservé.")
          }
        } else {
          // photo.pixelBuffer absent : aucune tentative de dématriçage à partir du fichier DNG
          // (fileDataRepresentation), dont les octets ne représentent pas un buffer de pixels brut.
          print("DaWishCam: photo.pixelBuffer indisponible pour cette capture. Aperçu non généré, fichier RAW conservé.")
        }
      } else {
        // Génération de l'aperçu RGB désactivée délibérément : le cadrage des 14 bits Bayer
        // significatifs dans le mot de 16 bits (justification gauche ou droite) n'est confirmé
        // ni par la documentation Apple ni par un test sur iPhone 14 physique. Produire un aperçu
        // non validé risquerait d'afficher une image trompeuse (ex. anormalement sombre). Le
        // fichier RAW (DNG) a déjà été persisté avec succès à ce stade, indépendamment de ceci.
        print("DaWishCam: aperçu RGB désactivé (dématriçage Bayer non encore validé sur iPhone 14 physique). Fichier RAW (DNG) conservé.")
      }

      let resultInfo = RawCaptureResultInfo(
        captureId: captureId,
        rawFilePath: rawFileUrl.path,
        previewFilePath: previewFileUrl?.path,
        rawPixelFormat: Int(detectedRawPixelFormat ?? 0),
        byteCount: rawData.count,
        previewWidth: previewWidth,
        previewHeight: previewHeight
      )

      activeCompletion?(.success(resultInfo))
    } catch {
      activeCompletion?(.failure(error))
    }

    activeCompletion = nil
  }

  /// Détermine le motif Bayer CFA à partir des métadonnées DNG/TIFF ou du code de format connu.
  ///
  /// Retourne `nil` si le motif ne peut être établi de façon fiable — aucune valeur de repli
  /// n'est présumée (Principe I de la Constitution : aucune capacité n'est tenue pour acquise).
  private func determineBayerLayout(fourCharCode: OSType, metadata: [String: Any]) -> BayerLayout? {
    // 1. Vérification dans les métadonnées TIFF/CFA (tag CFAPattern)
    if let tiffDict = metadata[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
       let cfaPattern = tiffDict["CFAPattern"] as? [Int], cfaPattern.count >= 4 {
      // 0: Red, 1: Green, 2: Blue
      if cfaPattern == [0, 1, 1, 2] { return .rggb }
      if cfaPattern == [2, 1, 1, 0] { return .bggr }
      if cfaPattern == [1, 0, 2, 1] { return .grbg }
      if cfaPattern == [1, 2, 0, 1] { return .gbrg }
    }

    // 2. Déduction à partir des codes FourCharCode Bayer connus d'Apple (mapping direct et
    //    documenté, pas une hypothèse : chaque constante désigne un motif CFA précis).
    switch fourCharCode {
    case kCVPixelFormatType_14Bayer_BGGR:
      return .bggr
    case kCVPixelFormatType_14Bayer_GRBG:
      return .grbg
    case kCVPixelFormatType_14Bayer_GBRG:
      return .gbrg
    case kCVPixelFormatType_14Bayer_RGGB:
      return .rggb
    default:
      // Code FourCharCode non reconnu : motif réellement indéterminable, pas de présomption.
      return nil
    }
  }

  /// Détermine la taille en octets d'un échantillon Bayer pour un format de pixel RAW connu.
  ///
  /// Retourne `nil` si la profondeur d'échantillon ne peut être établie de façon fiable pour ce
  /// format — aucune heuristique basée sur le stride ou la taille du buffer n'est utilisée.
  ///
  /// Les quatre constantes `kCVPixelFormatType_14Bayer_*` sont documentées par Apple comme des
  /// échantillons Bayer 14 bits emballés dans des mots de 16 bits (2 octets) en little-endian ;
  /// ce n'est donc pas une supposition mais une donnée directement issue de la définition du
  /// format. Le cadrage exact des 14 bits significatifs dans le mot de 16 bits (justifié à
  /// gauche ou à droite) n'est en revanche pas documenté de façon certaine : voir le commentaire
  /// dans `CpuBilinearDemosaicer` et le rapport d'audit pour ce point, qui nécessite une
  /// vérification empirique sur iPhone 14 physique.
  private func bayerSampleByteSize(fourCharCode: OSType) -> Int? {
    switch fourCharCode {
    case kCVPixelFormatType_14Bayer_BGGR,
         kCVPixelFormatType_14Bayer_GRBG,
         kCVPixelFormatType_14Bayer_GBRG,
         kCVPixelFormatType_14Bayer_RGGB:
      return 2
    default:
      // Format non reconnu parmi les formats Bayer RAW documentés : profondeur indéterminable.
      return nil
    }
  }
}
