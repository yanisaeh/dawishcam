import 'package:flutter_test/flutter_test.dart';
import 'package:dawishcam/src/bridge/camera_models.dart';

void main() {
  group('CameraDeviceInfo tests', () {
    test('instantiates with dynamic boundaries and parses correctly from map', () {
      final map = {
        'isBayerRawSupported': true,
        'detectedRawPixelFormat': 12345,
        'hasFlash': true,
        'minIso': 25.0,
        'maxIso': 1600.0,
        'minExposureDurationSeconds': 0.001,
        'maxExposureDurationSeconds': 0.25,
        'isFocusLockSupported': true,
      };

      final info = CameraDeviceInfo.fromMap(map);

      expect(info.isBayerRawSupported, isTrue);
      expect(info.detectedRawPixelFormat, equals(12345));
      expect(info.hasFlash, isTrue);
      expect(info.minIso, equals(25.0));
      expect(info.maxIso, equals(1600.0));
      expect(info.isFocusLockSupported, isTrue);
    });

    test('validates ISO within discovered dynamic range', () {
      const info = CameraDeviceInfo(
        isBayerRawSupported: true,
        hasFlash: true,
        isFlashSupported: true,
        minIso: 100.0,
        maxIso: 800.0,
        isFocusLockSupported: true,
      );

      // Limites découvertes
      expect(info.isIsoValid(100.0), isTrue);
      expect(info.isIsoValid(800.0), isTrue);
      expect(info.isIsoValid(400.0), isTrue);

      // Rejet des valeurs hors plage découverte
      expect(info.isIsoValid(99.9), isFalse);
      expect(info.isIsoValid(800.1), isFalse);
    });

    test('validates exposure duration within discovered dynamic range', () {
      const info = CameraDeviceInfo(
        isBayerRawSupported: true,
        hasFlash: false,
        isFlashSupported: false,
        minExposureDurationSeconds: 0.0001,
        maxExposureDurationSeconds: 0.5,
        isFocusLockSupported: true,
      );

      expect(info.isExposureDurationValid(0.0001), isTrue);
      expect(info.isExposureDurationValid(0.5), isTrue);
      expect(info.isExposureDurationValid(0.01), isTrue);

      expect(info.isExposureDurationValid(0.00009), isFalse);
      expect(info.isExposureDurationValid(0.5001), isFalse);
    });

    test('validates lens position if focus lock supported', () {
      const infoSupported = CameraDeviceInfo(
        isBayerRawSupported: true,
        hasFlash: true,
        isFlashSupported: true,
        isFocusLockSupported: true,
      );

      expect(infoSupported.isLensPositionValid(0.0), isTrue);
      expect(infoSupported.isLensPositionValid(1.0), isTrue);
      expect(infoSupported.isLensPositionValid(0.5), isTrue);
      expect(infoSupported.isLensPositionValid(-0.1), isFalse);
      expect(infoSupported.isLensPositionValid(1.1), isFalse);

      const infoUnsupported = CameraDeviceInfo(
        isBayerRawSupported: true,
        hasFlash: true,
        isFlashSupported: true,
        isFocusLockSupported: false,
      );

      expect(infoUnsupported.isLensPositionValid(0.5), isFalse);
    });
  });

  group('CameraControlState tests', () {
    test('default state has disabled flash and no active overlay', () {
      const state = CameraControlState();
      expect(state.flashMode, equals(FlashMode.disabled));
      expect(state.activeOverlay, equals(ManualControlOverlay.none));
      expect(state.iso, isNull);
      expect(state.exposureDurationSeconds, isNull);
      expect(state.lensPosition, isNull);
    });

    test('copyWith updates state correctly', () {
      const state = CameraControlState();
      final updated = state.copyWith(
        iso: 200.0,
        flashMode: FlashMode.enabled,
        activeOverlay: ManualControlOverlay.iso,
      );

      expect(updated.iso, equals(200.0));
      expect(updated.flashMode, equals(FlashMode.enabled));
      expect(updated.activeOverlay, equals(ManualControlOverlay.iso));
    });
  });

  group('RawCaptureResult tests', () {
    test('parses capture result with status and byteCount', () {
      final map = {
        'captureId': 'raw_123',
        'rawFilePath': '/path/to/capture.raw',
        'rawPixelFormat': 42,
        'byteCount': 1024,
        'status': 'completed',
      };

      final result = RawCaptureResult.fromMap(map);
      expect(result.captureId, equals('raw_123'));
      expect(result.rawFilePath, equals('/path/to/capture.raw'));
      expect(result.byteCount, equals(1024));
      expect(result.status, equals(CaptureStatus.completed));
    });
  });
}
