# Data Model: Complete DaWishCam MVP

**Feature**: `001-complete-camera-mvp`
**Date**: 2026-10-08
**Status**: Draft

## Entities

### 1. CameraDeviceInfo
Représente les capacités matérielles découvertes dynamiquement sur l'appareil cible (aucune valeur n'est présumée ou codée en dur).

- **`isBayerRawSupported`** (`bool`) : `true` si au moins un format retourné par `availableRawPhotoPixelFormatTypes` est validé par `AVCapturePhotoOutput.isBayerRAWPixelFormat(_:)`, sinon `false`.
- **`detectedRawPixelFormat`** (`int?`) : Code FourCharCode du format Bayer RAW vérifié expérimentalement (ou `null` si non disponible).
- **`hasFlash`** (`bool`) : Présence et disponibilité réelle du flash (`device.hasFlash`).
- **`minIso`** (`double?`) : Valeur minimale issue d'`activeFormat.minISO` (ou `null` si indisponible).
- **`maxIso`** (`double?`) : Valeur maximale issue d'`activeFormat.maxISO` (ou `null` si indisponible).
- **`minExposureDurationSeconds`** (`double?`) : Durée minimale issue d'`activeFormat.minExposureDuration` (ou `null` si indisponible).
- **`maxExposureDurationSeconds`** (`double?`) : Durée maximale issue d'`activeFormat.maxExposureDuration` (ou `null` si indisponible).
- **`isFocusLockSupported`** (`bool`) : Indique si `isLockingFocusWithCustomLensPositionSupported` est vrai sur le format actif.

**Règles de validation** :
- Les bornes de réglages manuels proviennent obligatoirement de la découverte dynamique sur l'appareil.
- Aucune capacité matérielle ou plage de valeur n'est tenue pour acquise.

---

### 2. CameraControlState
Encapsule les réglages manuels demandés et l'état des contrôles de l'interface.

- **`iso`** (`double?`) : Sensibilité manuelle sélectionnée, bornée par `[minIso, maxIso]`.
- **`exposureDurationSeconds`** (`double?`) : Durée d'exposition manuelle sélectionnée, bornée par `[minExposureDurationSeconds, maxExposureDurationSeconds]`.
- **`lensPosition`** (`double?`) : Position de focus lentille, bornée par `[0.0, 1.0]`.
- **`flashMode`** (`FlashMode`: `disabled`, `enabled`) : Mode du flash.
- **`activeOverlay`** (`ManualControlOverlay`: `none`, `iso`, `shutter`, `focus`) : Contrôle contextuel actuellement affiché au-dessus du viseur.

**Règles de validation & Invariants** :
- `flashMode` ne peut être basculé à `enabled` que si `hasFlash == true`. Si le flash est indisponible, le contrôle est désactivé ou masqué.
- `torchMode` est maintenu à `.off` en permanence.
- La fermeture d'une surimpression (`activeOverlay = none`) rétablit le viseur sans encombrement tout en maintenant les valeurs de configuration actives.

---

### 3. ViewfinderStreamState
Représente l'état du flux vidéo de prévisualisation en direct.

- **`textureId`** (`int?`) : Identifiant de la texture candidate Flutter pour le rendu du flux vidéo natif.
- **`targetFps`** (`int`) : Cadence cible de présentation du preview fixée à 24 FPS.
- **`lifecycleState`** (`ViewfinderLifecycle`: `uninitialized`, `streaming`, `paused`, `disposed`).

**Invariants** :
- Le viseur en direct utilise le flux vidéo natif AVFoundation approprié, distinct du traitement des captures RAW.
- Aucun réglage de cadence capteur ou preview n'est exposé à l'utilisateur.

---

### 4. RawCaptureSession & RawCaptureResult
Représente le cycle de vie et le résultat d'une capture photo RAW.

- **`captureId`** (`String`) : Identifiant unique de la capture.
- **`status`** (`CaptureStatus`: `idle`, `capturing`, `persisting`, `demosaicing`, `completed`, `failed`).
- **`rawFilePath`** (`String?`) : Emplacement de stockage du fichier de données brutes Bayer RAW persisté.
- **`rawPixelFormat`** (`int?`) : Code FourCharCode du format de pixel RAW utilisé.
- **`byteCount`** (`int?`) : Taille en octets du buffer brut persisté.
- **`errorCode`** (`String?`) : Code d'erreur en cas d'échec (ex: `RAW_UNAVAILABLE`, `STORAGE_ERROR`).

**Règles de validation & Découplage** :
- Si `isBayerRawSupported == false`, toute tentative de capture échoue avec l'erreur `RAW_UNAVAILABLE`.
- Aucun fichier JPEG ou HEIF n'est produit ni persisté en fallback.
- Le transport du résultat de capture (métadonnées) est strictement dissocié du transport de gros buffers d'image (le buffer RGB dématricé issu de la capture ne transite pas par le payload du MethodChannel).
