import 'package:flutter/material.dart';

/// Widget de rendu du viseur de la caméra.
///
/// Affiche la texture native Flutter (`Texture`) connectée au contrôleur de session
/// AVFoundation qui régule la présentation à 24 FPS.
class ViewfinderWidget extends StatelessWidget {
  final int? textureId;

  const ViewfinderWidget({
    super.key,
    required this.textureId,
  });

  @override
  Widget build(BuildContext context) {
    if (textureId == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white70,
            ),
            SizedBox(height: 16),
            Text(
              'Initialisation du viseur...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: Texture(textureId: textureId!),
      ),
    );
  }
}
