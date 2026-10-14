import Foundation

/// Agencement des filtres de couleur (CFA) de la matrice Bayer.
public enum BayerLayout {
  case rggb
  case bggr
  case grbg
  case gbrg
}

/// Pipeline minimal de dématriçage bilinéaire sur CPU pour DaWishCam.
///
/// Implémente le traitement `Bayer RAW → dématriçage CPU → RGB → preview`
/// conformément aux Principes III et IV de la Constitution :
/// - Aucune hypothèse fixe sur le motif Bayer (layout déterminé dynamiquement) ;
/// - Prise en charge du pas mémoire réel (`bytesPerRow`) et de la profondeur de bit ;
/// - Aucune courbe de virage (tone curve), ni netteté, ni réduction de bruit, ni HDR ;
/// - Traitement CPU exclusif.
public class CpuBilinearDemosaicer {

  public init() {}

  /// Dématrice un buffer Bayer CFA en composantes RGB sur CPU.
  ///
  /// - Parameters:
  ///   - pixelBytes: Pointeur vers les octets bruts du buffer de pixels.
  ///   - width: Largeur réelle en pixels.
  ///   - height: Hauteur réelle en pixels.
  ///   - bytesPerRow: Pas en octets par ligne (stride).
  ///   - bytesPerPixel: Taille d'un échantillon en octets (1 pour 8 bits, 2 pour 14/16 bits).
  ///   - layout: Motif Bayer découvert expérimentalement.
  /// - Returns: Données RGB dématricées pour la prévisualisation.
  public func demosaicBayerToRGB(
    pixelBytes: UnsafeRawPointer,
    width: Int,
    height: Int,
    bytesPerRow: Int,
    bytesPerPixel: Int,
    layout: BayerLayout
  ) -> Data? {
    guard width > 2 && height > 2, bytesPerPixel >= 1 else { return nil }

    let totalPixels = width * height
    var rgbData = Data(count: totalPixels * 3)

    // Fonction de lecture d'un échantillon normalisé sur 8 bits
    let readSample: (Int, Int) -> UInt32 = { (x: Int, y: Int) -> UInt32 in
      let clampedX = min(max(x, 0), width - 1)
      let clampedY = min(max(y, 0), height - 1)
      let offset = clampedY * bytesPerRow + clampedX * bytesPerPixel

      if bytesPerPixel == 2 {
        let val16 = pixelBytes.load(fromByteOffset: offset, as: UInt16.self)
        // Échantillon Bayer 14 bits emballé sur 16 bits (little-endian), conversion linéaire 8
        // bits sans courbe. HYPOTHÈSE NON VÉRIFIÉE SUR MATÉRIEL : ce décalage >> 8 suppose que
        // les 14 bits significatifs sont justifiés à gauche dans le mot de 16 bits (octets de
        // poids fort en tête). La documentation Apple confirme l'emballage 14-bits/16-bits mais
        // ne documente pas explicitement ce cadrage. Si les bits significatifs sont au contraire
        // justifiés à droite, cet aperçu sera anormalement sombre — à confirmer par comparaison
        // avec un visualiseur DNG de référence lors de la validation sur iPhone 14 physique.
        return UInt32(val16 >> 8)
      } else {
        let val8 = pixelBytes.load(fromByteOffset: offset, as: UInt8.self)
        return UInt32(val8)
      }
    }

    rgbData.withUnsafeMutableBytes { outBytes in
      guard let outPtr = outBytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

      for y in 0..<height {
        let isEvenRow = (y % 2 == 0)

        for x in 0..<width {
          let isEvenCol = (x % 2 == 0)
          let outIdx = (y * width + x) * 3

          // Déterminer le type de pixel (R, Gr, Gb, B) selon le layout dynamique
          let pixelType = getPixelType(isEvenRow: isEvenRow, isEvenCol: isEvenCol, layout: layout)

          var r: UInt32 = 0
          var g: UInt32 = 0
          var b: UInt32 = 0

          switch pixelType {
          case .red:
            r = readSample(x, y)
            g = (readSample(x, y - 1) + readSample(x, y + 1) +
                 readSample(x - 1, y) + readSample(x + 1, y)) / 4
            b = (readSample(x - 1, y - 1) + readSample(x + 1, y - 1) +
                 readSample(x - 1, y + 1) + readSample(x + 1, y + 1)) / 4

          case .greenOnRedRow:
            g = readSample(x, y)
            r = (readSample(x - 1, y) + readSample(x + 1, y)) / 2
            b = (readSample(x, y - 1) + readSample(x, y + 1)) / 2

          case .greenOnBlueRow:
            g = readSample(x, y)
            r = (readSample(x, y - 1) + readSample(x, y + 1)) / 2
            b = (readSample(x - 1, y) + readSample(x + 1, y)) / 2

          case .blue:
            b = readSample(x, y)
            g = (readSample(x, y - 1) + readSample(x, y + 1) +
                 readSample(x - 1, y) + readSample(x + 1, y)) / 4
            r = (readSample(x - 1, y - 1) + readSample(x + 1, y - 1) +
                 readSample(x - 1, y + 1) + readSample(x + 1, y + 1)) / 4
          }

          outPtr[outIdx] = UInt8(min(255, r))
          outPtr[outIdx + 1] = UInt8(min(255, g))
          outPtr[outIdx + 2] = UInt8(min(255, b))
        }
      }
    }

    return rgbData
  }

  private enum PixelChannel {
    case red
    case greenOnRedRow
    case greenOnBlueRow
    case blue
  }

  private func getPixelType(isEvenRow: Bool, isEvenCol: Bool, layout: BayerLayout) -> PixelChannel {
    switch layout {
    case .rggb:
      if isEvenRow && isEvenCol { return .red }
      if isEvenRow && !isEvenCol { return .greenOnRedRow }
      if !isEvenRow && isEvenCol { return .greenOnBlueRow }
      return .blue

    case .bggr:
      if isEvenRow && isEvenCol { return .blue }
      if isEvenRow && !isEvenCol { return .greenOnBlueRow }
      if !isEvenRow && isEvenCol { return .greenOnRedRow }
      return .red

    case .grbg:
      if isEvenRow && isEvenCol { return .greenOnRedRow }
      if isEvenRow && !isEvenCol { return .red }
      if !isEvenRow && isEvenCol { return .blue }
      return .greenOnBlueRow

    case .gbrg:
      if isEvenRow && isEvenCol { return .greenOnBlueRow }
      if isEvenRow && !isEvenCol { return .blue }
      if !isEvenRow && isEvenCol { return .red }
      return .greenOnRedRow
    }
  }
}
