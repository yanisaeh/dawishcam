import 'package:flutter/material.dart';
import '../bridge/camera_models.dart';

/// Composant de surimpression contextuelle pour les réglages manuels (ISO, Vitesse, Focus).
///
/// Intègre des contrôles discrets sans transformer l'écran en panneau permanent
/// ni masquer inutilement le viseur.
class ManualControlsOverlay extends StatelessWidget {
  final CameraDeviceInfo deviceInfo;
  final CameraControlState controlState;
  final ValueChanged<ManualControlOverlay> onSelectOverlay;
  final ValueChanged<double> onIsoChanged;
  final ValueChanged<double> onExposureChanged;
  final ValueChanged<double> onFocusChanged;

  const ManualControlsOverlay({
    super.key,
    required this.deviceInfo,
    required this.controlState,
    required this.onSelectOverlay,
    required this.onIsoChanged,
    required this.onExposureChanged,
    required this.onFocusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Curseur contextuel actif (si une surimpression est sélectionnée)
        if (controlState.activeOverlay != ManualControlOverlay.none)
          _buildActiveSlider(),

        const SizedBox(height: 8),

        // Ligne des indicateurs / boutons discrets
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIndicatorPill(
              label: 'ISO',
              valueText: controlState.iso != null
                  ? controlState.iso!.toStringAsFixed(0)
                  : '--',
              isSelected: controlState.activeOverlay == ManualControlOverlay.iso,
              isEnabled: deviceInfo.minIso != null && deviceInfo.maxIso != null,
              onTap: () => onSelectOverlay(ManualControlOverlay.iso),
            ),
            const SizedBox(width: 12),
            _buildIndicatorPill(
              label: 'SEC',
              valueText: _formatExposureDuration(controlState.exposureDurationSeconds),
              isSelected: controlState.activeOverlay == ManualControlOverlay.shutter,
              isEnabled: deviceInfo.minExposureDurationSeconds != null &&
                  deviceInfo.maxExposureDurationSeconds != null,
              onTap: () => onSelectOverlay(ManualControlOverlay.shutter),
            ),
            const SizedBox(width: 12),
            _buildIndicatorPill(
              label: 'FOCUS',
              valueText: controlState.lensPosition != null
                  ? controlState.lensPosition!.toStringAsFixed(2)
                  : '--',
              isSelected: controlState.activeOverlay == ManualControlOverlay.focus,
              isEnabled: deviceInfo.isFocusLockSupported,
              onTap: () => onSelectOverlay(ManualControlOverlay.focus),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveSlider() {
    final overlay = controlState.activeOverlay;
    double min = 0;
    double max = 1;
    double current = 0;
    ValueChanged<double> onChanged = (_) {};

    switch (overlay) {
      case ManualControlOverlay.iso:
        if (deviceInfo.minIso == null || deviceInfo.maxIso == null) {
          return const SizedBox.shrink();
        }
        min = deviceInfo.minIso!;
        max = deviceInfo.maxIso!;
        current = (controlState.iso ?? min).clamp(min, max);
        onChanged = onIsoChanged;

      case ManualControlOverlay.shutter:
        if (deviceInfo.minExposureDurationSeconds == null ||
            deviceInfo.maxExposureDurationSeconds == null) {
          return const SizedBox.shrink();
        }
        min = deviceInfo.minExposureDurationSeconds!;
        max = deviceInfo.maxExposureDurationSeconds!;
        current = (controlState.exposureDurationSeconds ?? min).clamp(min, max);
        onChanged = onExposureChanged;

      case ManualControlOverlay.focus:
        if (!deviceInfo.isFocusLockSupported) {
          return const SizedBox.shrink();
        }
        min = 0.0;
        max = 1.0;
        current = (controlState.lensPosition ?? 0.5).clamp(0.0, 1.0);
        onChanged = onFocusChanged;

      case ManualControlOverlay.none:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 0.8),
      ),
      child: SliderTheme(
        data: SliderThemeData(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          activeTrackColor: Colors.amber,
          inactiveTrackColor: Colors.white24,
          thumbColor: Colors.white,
        ),
        child: Slider(
          value: current,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildIndicatorPill({
    required String label,
    required String valueText,
    required bool isSelected,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber.withValues(alpha: 0.25)
              : Colors.black45,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.white24,
            width: isSelected ? 1.5 : 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.amber : Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              valueText,
              style: TextStyle(
                color: isEnabled ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExposureDuration(double? seconds) {
    if (seconds == null) return '--';
    if (seconds < 1.0 && seconds > 0) {
      final denominator = (1.0 / seconds).round();
      return '1/$denominator';
    }
    return '${seconds.toStringAsFixed(1)}s';
  }
}
