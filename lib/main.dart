import 'package:flutter/material.dart';
import 'src/ui/camera_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DaWishCamApp());
}

/// Application racine de DaWishCam.
class DaWishCamApp extends StatelessWidget {
  const DaWishCamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DaWishCam',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.amber,
          surface: Colors.black,
        ),
      ),
      home: const CameraScreen(),
    );
  }
}
