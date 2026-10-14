/// Modèles de données pour le bridge de caméra DaWishCam.
///
/// Reflète fidèlement les entités définies dans `data-model.md` sans aucune
/// valeur matérielle supposée ou codée en dur.
library;

enum FlashMode {
  disabled,
  enabled,
}

enum ManualControlOverlay {
  none,
  iso,
  shutter,
  focus,
}

enum ViewfinderLifecycle {
  uninitialized,
  streaming,
  paused,
  disposed,
}

enum CaptureStatus {
  idle,
  capturing,
  persisting,
  demosaicing,
  completed,
  failed,
}

/// Capacités et plages opérationnelles découvertes dynamiquement sur l'appareil.
class CameraDeviceInfo {
  final bool isBayerRawSupported;
  final int? detectedRawPixelFormat;
  final bool hasFlash;
  final bool isFlashSupported;
  final double? minIso;
  final double? maxIso;
  final double? minExposureDurationSeconds;
  final double? maxExposureDurationSeconds;
  final bool isFocusLockSupported;

  const CameraDeviceInfo({
    required this.isBayerRawSupported,
    this.detectedRawPixelFormat,
    required this.hasFlash,
    required this.isFlashSupported,
    this.minIso,
    this.maxIso,
    this.minExposureDurationSeconds,
    this.maxExposureDurationSeconds,
    required this.isFocusLockSupported,
  });

  factory CameraDeviceInfo.fromMap(Map<dynamic, dynamic> map) {
    return CameraDeviceInfo(
      isBayerRawSupported: map['isBayerRawSupported'] as bool? ?? false,
      detectedRawPixelFormat: map['detectedRawPixelFormat'] as int?,
      hasFlash: map['hasFlash'] as bool? ?? false,
      isFlashSupported: map['isFlashSupported'] as bool? ?? (map['hasFlash'] as bool? ?? false),
      minIso: (map['minIso'] as num?)?.toDouble(),
      maxIso: (map['maxIso'] as num?)?.toDouble(),
      minExposureDurationSeconds:
          (map['minExposureDurationSeconds'] as num?)?.toDouble(),
      maxExposureDurationSeconds:
          (map['maxExposureDurationSeconds'] as num?)?.toDouble(),
      isFocusLockSupported: map['isFocusLockSupported'] as bool? ?? false,
    );
  }

  /// Vérifie si une valeur ISO est comprise dans la plage découverte.
  bool isIsoValid(double iso) {
    if (minIso == null || maxIso == null) return false;
    return iso >= minIso! && iso <= maxIso!;
  }

  /// Vérifie si une durée d'exposition est comprise dans la plage découverte.
  bool isExposureDurationValid(double seconds) {
    if (minExposureDurationSeconds == null || maxExposureDurationSeconds == null) {
      return false;
    }
    return seconds >= minExposureDurationSeconds! &&
        seconds <= maxExposureDurationSeconds!;
  }

  /// Vérifie si une position de focus est valide (0.0 à 1.0).
  bool isLensPositionValid(double position) {
    if (!isFocusLockSupported) return false;
    return position >= 0.0 && position <= 1.0;
  }
}

/// État courant des contrôles manuels et des surimpressions d'interface.
class CameraControlState {
  final double? iso;
  final double? exposureDurationSeconds;
  final double? lensPosition;
  final FlashMode flashMode;
  final ManualControlOverlay activeOverlay;

  const CameraControlState({
    this.iso,
    this.exposureDurationSeconds,
    this.lensPosition,
    this.flashMode = FlashMode.disabled,
    this.activeOverlay = ManualControlOverlay.none,
  });

  CameraControlState copyWith({
    double? iso,
    double? exposureDurationSeconds,
    double? lensPosition,
    FlashMode? flashMode,
    ManualControlOverlay? activeOverlay,
  }) {
    return CameraControlState(
      iso: iso ?? this.iso,
      exposureDurationSeconds:
          exposureDurationSeconds ?? this.exposureDurationSeconds,
      lensPosition: lensPosition ?? this.lensPosition,
      flashMode: flashMode ?? this.flashMode,
      activeOverlay: activeOverlay ?? this.activeOverlay,
    );
  }
}

/// État du flux vidéo de prévisualisation dans Flutter.
class ViewfinderStreamState {
  final int? textureId;
  final int targetFps;
  final ViewfinderLifecycle lifecycleState;

  const ViewfinderStreamState({
    this.textureId,
    this.targetFps = 24,
    this.lifecycleState = ViewfinderLifecycle.uninitialized,
  });

  ViewfinderStreamState copyWith({
    int? textureId,
    int? targetFps,
    ViewfinderLifecycle? lifecycleState,
  }) {
    return ViewfinderStreamState(
      textureId: textureId ?? this.textureId,
      targetFps: targetFps ?? this.targetFps,
      lifecycleState: lifecycleState ?? this.lifecycleState,
    );
  }
}

/// Résultat d'une capture photo Bayer RAW persistée.
class RawCaptureResult {
  final String captureId;
  final String? rawFilePath;
  final String? previewFilePath;
  final int? rawPixelFormat;
  final int? byteCount;
  final int? previewWidth;
  final int? previewHeight;
  final CaptureStatus status;
  final String? errorCode;

  const RawCaptureResult({
    required this.captureId,
    this.rawFilePath,
    this.previewFilePath,
    this.rawPixelFormat,
    this.byteCount,
    this.previewWidth,
    this.previewHeight,
    this.status = CaptureStatus.completed,
    this.errorCode,
  });

  factory RawCaptureResult.fromMap(Map<dynamic, dynamic> map) {
    final statusStr = map['status'] as String?;
    final parsedStatus = switch (statusStr) {
      'capturing' => CaptureStatus.capturing,
      'persisting' => CaptureStatus.persisting,
      'demosaicing' => CaptureStatus.demosaicing,
      'completed' => CaptureStatus.completed,
      'failed' => CaptureStatus.failed,
      _ => CaptureStatus.completed,
    };

    return RawCaptureResult(
      captureId: map['captureId'] as String? ?? '',
      rawFilePath: map['rawFilePath'] as String?,
      previewFilePath: map['previewFilePath'] as String?,
      rawPixelFormat: map['rawPixelFormat'] as int?,
      byteCount: map['byteCount'] as int?,
      previewWidth: map['previewWidth'] as int?,
      previewHeight: map['previewHeight'] as int?,
      status: parsedStatus,
      errorCode: map['errorCode'] as String?,
    );
  }
}
