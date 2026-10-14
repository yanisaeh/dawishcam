import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bridge/camera_bridge.dart';
import '../bridge/camera_models.dart';
import 'viewfinder_widget.dart';
import 'capture_controls_widget.dart';
import 'manual_controls_overlay.dart';

/// Écran principal de prise de vue de DaWishCam.
///
/// Met en œuvre la hiérarchie visuelle inspirée d'iOS :
/// - Viseur dominant plein écran ;
/// - Bouton de déclencheur principal en zone inférieure ;
/// - Contrôle du flash accessible dans la barre supérieure ;
/// - Surimpressions discrètes pour les réglages manuels (ISO, vitesse, focus).
class CameraScreen extends StatefulWidget {
  final CameraBridge? bridge;

  const CameraScreen({super.key, this.bridge});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  late final CameraBridge _bridge;

  ViewfinderStreamState _streamState = const ViewfinderStreamState();
  CameraDeviceInfo? _deviceInfo;
  CameraControlState _controlState = const CameraControlState();

  bool _isCapturing = false;
  bool _showShutterFlash = false;
  String? _statusBannerMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bridge = widget.bridge ?? CameraBridge();
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _bridge.pausePreview();
      setState(() {
        _streamState = _streamState.copyWith(lifecycleState: ViewfinderLifecycle.paused);
      });
    } else if (state == AppLifecycleState.resumed) {
      _bridge.resumePreview();
      setState(() {
        _streamState = _streamState.copyWith(lifecycleState: ViewfinderLifecycle.streaming);
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final (:textureId, :deviceInfo) = await _bridge.initializeCamera();
      if (!mounted) return;
      setState(() {
        _deviceInfo = deviceInfo;
        _streamState = _streamState.copyWith(
          textureId: textureId,
          lifecycleState: ViewfinderLifecycle.streaming,
        );
        // Initialiser les valeurs de contrôle sur les bornes découvertes
        _controlState = _controlState.copyWith(
          iso: deviceInfo.minIso,
          exposureDurationSeconds: deviceInfo.minExposureDurationSeconds,
          lensPosition: deviceInfo.isFocusLockSupported ? 0.5 : null,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusBannerMessage = 'Erreur initialisation caméra: $e';
      });
    }
  }

  Future<void> _handleCapture() async {
    if (_isCapturing) return;

    if (_deviceInfo?.isBayerRawSupported != true) {
      _showFeedbackSnackBar('Bayer RAW non disponible sur cette configuration.');
      return;
    }

    setState(() {
      _isCapturing = true;
      _showShutterFlash = true;
    });

    // Retour visuel d'obturateur (flash blanc bref)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() => _showShutterFlash = false);
      }
    });

    try {
      final result = await _bridge.captureBayerRaw();
      if (!mounted) return;
      _showFeedbackSnackBar('Bayer RAW capturé (${result.byteCount ?? 0} octets)');
    } on PlatformException catch (e) {
      if (!mounted) return;
      _showFeedbackSnackBar('Erreur capture: ${e.message ?? e.code}');
    } catch (e) {
      if (!mounted) return;
      _showFeedbackSnackBar('Erreur inattendue: $e');
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _showFeedbackSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.black87,
      ),
    );
  }

  void _toggleFlash() {
    if (_deviceInfo?.isFlashSupported != true) {
      _showFeedbackSnackBar('Flash non disponible sur cette configuration.');
      return;
    }

    final newMode = _controlState.flashMode == FlashMode.disabled
        ? FlashMode.enabled
        : FlashMode.disabled;

    _bridge.setFlashMode(newMode == FlashMode.enabled);
    setState(() {
      _controlState = _controlState.copyWith(flashMode: newMode);
    });
  }

  void _selectOverlay(ManualControlOverlay overlay) {
    setState(() {
      _controlState = _controlState.copyWith(
        activeOverlay: _controlState.activeOverlay == overlay
            ? ManualControlOverlay.none
            : overlay,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasFlash = _deviceInfo?.isFlashSupported ?? false;
    final isBayerRawSupported = _deviceInfo?.isBayerRawSupported ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Viseur dominant plein écran
          ViewfinderWidget(textureId: _streamState.textureId),

          // 2. Flash visuel d'obturateur (feedback de capture)
          if (_showShutterFlash)
            IgnorePointer(
              child: Container(color: Colors.white70),
            ),

          // 3. Barre supérieure d'état et contrôle du flash
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Bouton Flash (accessible sur l'écran principal)
                    IconButton(
                      icon: Icon(
                        _controlState.flashMode == FlashMode.enabled
                            ? Icons.flash_on
                            : Icons.flash_off,
                        color: hasFlash
                            ? (_controlState.flashMode == FlashMode.enabled
                                ? Colors.amber
                                : Colors.white)
                            : Colors.white38,
                      ),
                      onPressed: hasFlash ? _toggleFlash : null,
                      tooltip: hasFlash
                          ? (_controlState.flashMode == FlashMode.enabled
                              ? 'Flash activé'
                              : 'Flash désactivé')
                          : 'Flash indisponible',
                    ),

                    // Badge d'état du format RAW
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isBayerRawSupported ? Colors.greenAccent : Colors.orangeAccent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isBayerRawSupported ? 'RAW 24 FPS' : 'RAW N/A',
                        style: TextStyle(
                          color: isBayerRawSupported ? Colors.greenAccent : Colors.orangeAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Surimpressions des réglages manuels (ISO, Vitesse, Focus)
          if (_deviceInfo != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: ManualControlsOverlay(
                  deviceInfo: _deviceInfo!,
                  controlState: _controlState,
                  onSelectOverlay: _selectOverlay,
                  onIsoChanged: (val) {
                    _bridge.setManualIso(val);
                    setState(() => _controlState = _controlState.copyWith(iso: val));
                  },
                  onExposureChanged: (val) {
                    _bridge.setManualExposure(val);
                    setState(() => _controlState = _controlState.copyWith(exposureDurationSeconds: val));
                  },
                  onFocusChanged: (val) async {
                    try {
                      await _bridge.setManualFocus(val);
                      if (mounted) {
                        setState(() => _controlState = _controlState.copyWith(lensPosition: val));
                      }
                    } on PlatformException catch (e) {
                      if (mounted) {
                        _showFeedbackSnackBar(e.message ?? 'Focus verrouillé non supporté');
                      }
                    }
                  },
                ),
              ),
            ),

          // 5. Zone inférieure : Déclencheur inspiré d'iOS
          Align(
            alignment: Alignment.bottomCenter,
            child: CaptureControlsWidget(
              onCapturePressed: _handleCapture,
              isCapturing: _isCapturing,
              isEnabled: isBayerRawSupported,
            ),
          ),

          // 6. Message de diagnostic si nécessaire
          if (_statusBannerMessage != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusBannerMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
