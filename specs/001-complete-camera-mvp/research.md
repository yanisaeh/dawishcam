# Phase 0 Research & Technical Decisions: Complete DaWishCam MVP

**Feature**: `001-complete-camera-mvp`
**Date**: 2026-10-08
**Status**: Completed

## 1. Viewfinder Rendering & iOS-Inspired UX Layout

### Decision
- **Flux du viseur en direct (Live Viewfinder)** : Le viseur en direct exploite le flux vidéo de prévisualisation natif approprié fourni par AVFoundation (et non un dématriçage continu de trames RAW still).
- **Preview Rendering Pipeline** : Retenir `FlutterTexture` (`FlutterTextureRegistry` et protocole `FlutterTexture` sous iOS) comme mécanisme candidat pour transmettre les buffers de prévisualisation natifs (`CVPixelBufferRef`) vers Flutter afin d'alimenter le viseur à une cadence de 24 FPS.
- **Validation des performances et de la mémoire** : Ne pas présumer a priori d'une absence de copie (« zero-copy ») ni d'un avantage de performance absolu. Le comportement mémoire, les éventuelles copies de buffers et les performances réelles devront être mesurés expérimentalement sur l'appareil cible avant de qualifier l'implémentation de zero-copy ou de considérer ce choix architectural comme optimal.
- **UI Architecture & Layout** :
  - Le viseur (`Texture` widget) occupe la majeure partie de l'écran.
  - Le bouton de capture principal est placé dans la zone inférieure selon les conventions familières d'une application caméra iOS.
  - Le contrôle du flash est disposé sous forme d'un contrôle superposé accessible sur l'écran principal (lorsque le flash est vérifié disponible).
  - Les contrôles manuels (ISO, vitesse d'obturation, mise au point) sont intégrés sous forme de superpositions discrètes et contextuelles au-dessus du viseur, sans transformer l'écran en panneau de réglages permanent ni masquer inutilement le cadrage.
- **Bridge Channels** : Utiliser un `MethodChannel` typé pour les commandes (initialisation, réglages manuels, déclenchement de capture) et un `EventChannel` pour le flux des états de l'appareil (capacités vérifiées, plages de valeurs, progression de capture, erreurs).

### Rationale
- Fulfills FR-016 through FR-020: garantit une ergonomie familière d'iOS tout en maintenant le viseur comme élément dominant.
- Satisfies Constitution Principle II: sépare rigoureusement la couche de présentation Flutter des couches natives de capture et de streaming.

### Alternatives Considered
- **UIKitView Platform View**: Écarté pour le flux continu en raison de la surcharge de composition graphique par rapport à une texture native.
- **Panneau de réglages permanent**: Écarté car il masquerait la zone de composition.

---

## 2. Experimental Verification of Bayer RAW Capabilities in AVFoundation

### Decision
Implémenter une routine d'interrogation dynamique des capacités matérielles dans la couche native Swift lors de l'initialisation de la session :
- Interroger les formats réellement retournés par `AVCapturePhotoOutput.availableRawPhotoPixelFormatTypes`.
- Identifier expérimentalement les formats Bayer RAW disponibles sur l'appareil cible en utilisant `AVCapturePhotoOutput.isBayerRAWPixelFormat(_:)`.
- Ne présumer d'aucun format Bayer 14-bit spécifique (RGGB, BGGR, etc.) comme garanti a priori sur l'iPhone 14 tant qu'il n'a pas été observé sur le matériel physique.
- Transmettre l'état de capacité vérifié (`isBayerRawSupported: Bool`, `detectedRawPixelFormat: UInt32?`) au bridge Dart.
- Si un format Bayer RAW est vérifié expérimentalement, configurer `AVCapturePhotoSettings(rawPhotoPixelFormatType: detectedRawPixelFormat, processedFormat: nil)` lors de la capture, en veillant à ne joindre aucun format traité (JPEG, HEIF).
- Si aucun format Bayer RAW n'est disponible sur la configuration/l'appareil courant, communiquer explicitement l'indisponibilité à l'utilisateur et désactiver le déclenchement plutôt que de basculer silencieusement vers un format compressé.

### Rationale
- Constitution Principle I exige formellement que les capacités matérielles et API de l'iPhone 14 soient prouvées expérimentalement et non supposées d'après la documentation.
- FR-003 et FR-004 imposent d'acquérir le format Bayer RAW uniquement lorsque la capacité est expérimentalement vérifiée, avec une interdiction stricte de fallback JPEG.

### Alternatives Considered
- **Présumer une liste fixe de formats Bayer 14-bit sans vérification dynamique**: Écarté car cela transforme des formats potentiels en fausses garanties matérielles.
- **Fallback automatique vers JPEG si RAW non supporté**: Strictement interdit par le Principe III de la Constitution.

---

## 3. CPU-First Minimal Demosaicing Pipeline for Still Captures

### Decision
Le pipeline de dématriçage concerne exclusivement le traitement de la capture photo RAW (et non le flux vidéo du viseur en direct) :
- **Entrée** : Buffer de capteur raw Bayer CFA non compressé acquis lors du déclenchement photo via `AVCapturePhoto`.
- **Traitement** : Interpolation bilinéaire minimale 2x2 / 3x3 sur CPU pour reconstruire les canaux Rouge, Vert et Bleu pour chaque pixel.
- **Sortie** : Buffer RGB 8 bits par canal servant à afficher la prévisualisation de la capture effectuée.
- **Périmètre strict du pipeline** : Buffer Raw de capture → Dématriçage bilinéaire CPU → RGB.
- **Exclusions strictes** : Aucune courbe de virage (tone curve), aucun HDR multi-images, aucun filtre de netteté (sharpening), aucune réduction de bruit, aucune matrice de balance des blancs personnalisée.

### Rationale
- Respecte strictement le Principe III (`Bayer RAW → Dématriçage → RGB → Preview`) et le Principe IV (implémentation de référence CPU avant toute accélération GPU/Metal).
- Dissocie clairement le rendu du viseur en direct du traitement de la photo acquise.

### Alternatives Considered
- **Dématriçage continu du flux live en RAW sur CPU à 24 FPS**: Rejeté car le live preview utilise le flux de prévisualisation AVFoundation natif approprié.
- **Shaders Metal / GPU**: Reportés conformément au Principe IV tant que les mesures CPU n'en démontrent pas l'absolue nécessité.
- **Apple CoreImage `CIRAWFilter`**: Écarté car les filtres RAW intégrés d'Apple appliquent des traitements correctifs automatiques contraires à la fidélité brute.

---

## 4. 24 FPS Preview Cadence Architecture

### Decision
- **Cadence de prévisualisation** : Réguler la présentation du preview dans Flutter à une cadence cible de 24 FPS.
- **Validation matérielle** : Vérifier expérimentalement les cadences de trames et formats réellement supportés par le format actif d'`AVCaptureDevice` sur l'iPhone 14. Ne pas imposer a priori une configuration matérielle fixe à 24 FPS au capteur tant que cette capacité n'a pas été validée sur l'appareil.
- **Contrôle utilisateur** : Aucun réglage de framerate (capteur ou preview) ne doit être exposé à l'utilisateur dans l'interface Flutter.

### Rationale
- Répond au Principe III de la Constitution et aux exigences FR-001/FR-002 : l'utilisateur dispose d'un preview rendu à 24 FPS, sans exposition de réglage de framerate.
- S'aligne avec le Principe I en vérifiant expérimentalement ce que le matériel accepte plutôt que de figer une configuration théorique d'AVFoundation.

### Alternatives Considered
- **Exposer un sélecteur de cadence**: Strictement interdit par la spécification et la Constitution.

---

## 5. Manual Controls & Hardware Range Discovery

### Decision
Découvrir les plages de paramètres opérationnels dynamiquement depuis `AVCaptureDevice` :
- Lire `activeFormat.minISO` et `activeFormat.maxISO`.
- Lire `activeFormat.minExposureDuration` et `activeFormat.maxExposureDuration`.
- Vérifier le support de verrouillage de position de lentille via `isLockingFocusWithCustomLensPositionSupported` (plage 0.0 à 1.0).
- Transmettre les plages réelles découvertes au bridge Flutter lors de l'initialisation afin de calibrer les curseurs sur les capacités réelles.
- Appliquer les réglages via `device.setExposureModeCustom(duration:iso:)` et `device.setFocusModeLocked(lensPosition:)` sous verrou `lockForConfiguration()`.

### Rationale
- Conforme aux Principes I (découverte empirique des limites réelles) et V (contrôles limités strictement à ISO, vitesse, focus et flash).

### Alternatives Considered
- **Plages codées en dur dans Flutter**: Écarté car les limites varient selon les objectifs et configurations.

---

## 6. Flash Verification & Strict Illumination Behavior

### Decision
- **Vérification empirique de disponibilité** : Interroger la capacité réelle du flash sur l'appareil cible et la configuration courante (`device.hasFlash`).
- **Gestion de la disponibilité** : Si le flash n'est pas disponible, l'application signale cette indisponibilité à l'utilisateur et désactive le contrôle plutôt que de présumer de son fonctionnement.
- **Règles d'illumination strictes (si disponible)** :
  - Flash activé : éclairage uniquement lors de la prise de vue (`photoSettings.flashMode = .on` lors de l'appel à `capturePhoto`).
  - Flash désactivé : aucun éclairage (`photoSettings.flashMode = .off`).
  - `torchMode` ne doit JAMAIS être utilisé pour la prévisualisation en direct (`device.torchMode = .off` garanti en continu).

### Rationale
- Respecte le Principe I (vérification de la disponibilité du flash avant utilisation) et le Principe V (règles strictes d'absence totale d'éclairage continu en preview).

### Alternatives Considered
- **Présumer que le flash est toujours présent**: Écarté pour éviter des comportements indéterminés ou des plantages sur des configurations non équipées ou non supportées.
- **Mode torche pour le preview**: Strictement interdit par la Constitution.

---

## 7. Storage & Data Persistence

### Decision
- Persister les captures Bayer RAW dans un emplacement de stockage de l'application permettant leur récupération ultérieure et la vérification de leur intégrité.
- Conserver le buffer de données brutes du capteur et ses métadonnées sans générer de fichier JPEG ou HEIF.

### Rationale
- Conforme au Principe III (aucune persistance JPEG) et préserve l'intégrité des données brutes sans contraindre prématurément le répertoire précis tant que les besoins d'accès fichiers ne sont pas arrêtés.
