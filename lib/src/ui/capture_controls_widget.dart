import 'package:flutter/material.dart';

/// Barre de capture inférieure inspirée de l'ergonomie familière d'iOS Camera.
///
/// Place le déclencheur principal au centre de la zone inférieure, facilement
/// accessible au pouce.
class CaptureControlsWidget extends StatelessWidget {
  final VoidCallback onCapturePressed;
  final bool isCapturing;
  final bool isEnabled;

  const CaptureControlsWidget({
    super.key,
    required this.onCapturePressed,
    this.isCapturing = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: GestureDetector(
          onTap: (isEnabled && !isCapturing) ? onCapturePressed : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isCapturing ? 68 : 74,
            height: isCapturing ? 68 : 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isEnabled ? Colors.white : Colors.white38,
                width: 4,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isEnabled
                      ? (isCapturing ? Colors.white60 : Colors.white)
                      : Colors.white24,
                ),
                child: isCapturing
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black54,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
