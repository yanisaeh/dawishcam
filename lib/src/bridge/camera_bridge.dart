import 'package:flutter/services.dart';
import 'camera_models.dart';

/// Service gérant la communication bidirectionnelle avec la couche native iOS.
///
/// Implémente le contrat d'interface défini dans `contracts/camera-channel.md`.
class CameraBridge {
  static const MethodChannel _channel = MethodChannel('com.dawishcam/camera');
  static const EventChannel _eventChannel = EventChannel('com.dawishcam/camera_events');

  Stream<Map<String, dynamic>>? _eventStream;

  /// Flux des événements de capture et d'erreurs en provenance de la couche native.
  Stream<Map<String, dynamic>> get events {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  /// Initialise la session caméra native, enregistre la texture et découvre dynamiquement les capacités.
  Future<({int textureId, CameraDeviceInfo deviceInfo})> initializeCamera() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('initializeCamera');
    if (result == null) {
      throw PlatformException(
        code: 'INITIALIZATION_FAILED',
        message: 'Native camera initialization returned null',
      );
    }

    final textureId = result['textureId'] as int;
    final deviceInfo = CameraDeviceInfo.fromMap(result);
    return (textureId: textureId, deviceInfo: deviceInfo);
  }

  /// Règle la sensibilité ISO manuelle sur le capteur.
  Future<void> setManualIso(double iso) async {
    await _channel.invokeMethod<void>('setManualIso', {'iso': iso});
  }

  /// Règle la durée d'exposition (vitesse d'obturation) sur le capteur.
  Future<void> setManualExposure(double durationSeconds) async {
    await _channel.invokeMethod<void>('setManualExposure', {
      'durationSeconds': durationSeconds,
    });
  }

  /// Règle la position de mise au point de la lentille (0.0 à 1.0).
  Future<void> setManualFocus(double lensPosition) async {
    await _channel.invokeMethod<void>('setManualFocus', {
      'lensPosition': lensPosition,
    });
  }

  /// Active ou désactive le flash pour la capture photo.
  Future<void> setFlashMode(bool enabled) async {
    await _channel.invokeMethod<void>('setFlashMode', {'enabled': enabled});
  }

  /// Déclenche la capture d'une photo en Bayer RAW.
  ///
  /// Lève une [PlatformException] avec le code `RAW_UNAVAILABLE` si la capacité
  /// Bayer RAW n'est pas supportée sur l'appareil cible.
  Future<RawCaptureResult> captureBayerRaw() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('captureBayerRaw');
    if (result == null) {
      throw PlatformException(
        code: 'CAPTURE_FAILED',
        message: 'Capture returned null',
      );
    }
    return RawCaptureResult.fromMap(result);
  }

  /// Met en pause le flux vidéo lors du passage en arrière-plan.
  Future<void> pausePreview() async {
    await _channel.invokeMethod<void>('pausePreview');
  }

  /// Réactive le flux vidéo lors du retour au premier plan.
  Future<void> resumePreview() async {
    await _channel.invokeMethod<void>('resumePreview');
  }
}
