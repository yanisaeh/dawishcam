# Tasks: Complete DaWishCam MVP

**Branch**: `001-complete-camera-mvp`
**Spec**: [spec.md](spec.md) | **Plan**: [plan.md](plan.md)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialisation du projet et mise en place de l'arborescence

- [ ] T001 Créer l'arborescence des dossiers du projet dans `lib/src/bridge/`, `lib/src/ui/` et `ios/Runner/Camera/`
- [ ] T002 [P] Mettre à jour les dépendances et assets du projet dans `pubspec.yaml`
- [ ] T003 [P] Configurer les autorisations caméra iOS (`NSCameraUsageDescription`) dans `ios/Runner/Info.plist`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Infrastructure de communication et modèles partagés indispensables aux User Stories

- [ ] T004 [P] Implémenter les modèles de données Dart (`CameraDeviceInfo`, `CameraControlState`, `ViewfinderStreamState`, `RawCaptureResult`) dans `lib/src/bridge/camera_models.dart` avec champs dynamiques découverts
- [ ] T005 [P] Implémenter le wrapper Flutter `MethodChannel` et `EventChannel` dans `lib/src/bridge/camera_bridge.dart` conformément au contrat `contracts/camera-channel.md`
- [ ] T006 [P] Implémenter le plugin natif Swift `CameraBridgePlugin` dans `ios/Runner/Camera/CameraBridgePlugin.swift` pour écouter les canaux `com.dawishcam/camera` et `com.dawishcam/camera_events`
- [ ] T007 Enregistrer `CameraBridgePlugin` dans `ios/Runner/AppDelegate.swift`

**Checkpoint**: Socle de communication en place — le développement des User Stories peut débuter

---

## Phase 3: User Story 1 - Live Viewfinder Preview at 24 FPS & iOS Layout (Priority: P1) 🎯 MVP

**Goal**: Fournir une interface caméra inspirée d'iOS avec un viseur dominant présentant le preview à 24 FPS via `FlutterTexture` à partir du flux vidéo natif, un déclencheur en zone inférieure et un accès au flash si disponible.

**Independent Test**: Lancer l'application sur l'appareil cible ; le viseur s'affiche et présente le preview à 24 FPS sans interaction, occupant la majeure partie de l'écran avec le bouton de capture en zone inférieure.

### Implementation for User Story 1

- [ ] T008 [P] [US1] Implémenter la session caméra native `CameraSessionController` dans `ios/Runner/Camera/CameraSessionController.swift` (réception du flux `AVCaptureVideoDataOutput`, régulation temporelle de la présentation du preview à 24 FPS vers `FlutterTexture`, sans imposer de cadence matérielle au capteur et sans exposer de réglage framerate)
- [ ] T009 [US1] Raccorder `CameraSessionController` à `CameraBridgePlugin.swift` pour gérer les appels `initializeCamera()`, `pausePreview()` et `resumePreview()`
- [ ] T010 [P] [US1] Implémenter le widget de rendu du viseur `ViewfinderWidget` dans `lib/src/ui/viewfinder_widget.dart` intégrant la `Texture` Flutter
- [ ] T011 [P] [US1] Implémenter la barre de capture inférieure avec le bouton déclencheur dans `lib/src/ui/capture_controls_widget.dart`
- [ ] T012 [US1] Assembler l'écran principal de prise de vue dans `lib/src/ui/camera_screen.dart` (mise en page dominée par le viseur, barre inférieure et barre supérieure d'état)
- [ ] T013 [US1] Mettre à jour `lib/main.dart` pour initialiser `CameraScreen` avec gestion des permissions caméra

**Checkpoint**: User Story 1 opérationnelle et testable de façon autonome (MVP fonctionnel)

---

## Phase 4: User Story 2 - Bayer RAW Still Capture & Minimal Processing (Priority: P2)

**Goal**: Déclencher la capture photo en Bayer RAW si supportée expérimentalement par le matériel/AVFoundation, exécuter le dématriçage bilinéaire minimal sur CPU pour l'aperçu photo, et persister le buffer RAW sans générer de JPEG/HEIF (ou lever une erreur explicite `RAW_UNAVAILABLE`).

**Independent Test**: Appuyer sur le déclencheur ; si le Bayer RAW est disponible, le buffer brut est acquis, dématricé sur CPU et persisté dans l'espace de l'application avec 0 JPEG produit ; si indisponible, l'erreur est notifiée sans fallback compressé.

### Implementation for User Story 2

- [ ] T014 [P] [US2] Implémenter l'algorithme de dématriçage bilinéaire sur CPU dans `ios/Runner/Camera/CpuBilinearDemosaicer.swift` (Bayer CFA → dématriçage CPU → RGB → preview, sans virage, ni netteté, ni réduction de bruit, ni HDR, ni balance des blancs personnalisée, sans imposer de contrainte 8 bits a priori)
- [ ] T015 [P] [US2] Implémenter le service de capture photo dans `ios/Runner/Camera/RawPhotoCaptureService.swift` (interrogation `availableRawPhotoPixelFormatTypes` et `isBayerRAWPixelFormat(_:)`, capture RAW via `AVCapturePhotoOutput`, persistance du fichier brut, appel au dématriceur CPU, gestion de l'erreur `RAW_UNAVAILABLE`)
- [ ] T016 [US2] Raccorder `RawPhotoCaptureService` à `CameraBridgePlugin.swift` pour la méthode `captureBayerRaw()` et la diffusion des événements de progression de capture
- [ ] T017 [US2] Implémenter le déclenchement de prise de vue et l'animation de retour visuel dans `lib/src/ui/capture_controls_widget.dart` et `lib/src/ui/camera_screen.dart`

**Checkpoint**: User Stories 1 et 2 complètes et testables indépendamment

---

## Phase 5: User Story 3 - Essential Manual Photographic Controls & Flash (Priority: P3)

**Goal**: Permettre le réglage manuel de l'ISO, de la vitesse d'obturation et de la mise au point dans les plages réelles découvertes sur l'appareil, ainsi que le contrôle du flash selon sa disponibilité réelle (actif uniquement au déclenchement, jamais en torche).

**Independent Test**: Manipuler les curseurs ISO, vitesse et focus : vérifier que le capteur s'ajuste dans les plages réelles sans masquer le viseur ; basculer le flash si disponible et vérifier qu'il s'allume uniquement lors de la prise de vue.

### Implementation for User Story 3

- [ ] T018 [P] [US3] Implémenter la découverte dynamique des plages matérielles et les réglages manuels dans `ios/Runner/Camera/CameraSessionController.swift` (`minISO`/`maxISO`, durée d'exposition, focus verrouillé, présence du flash)
- [ ] T019 [US3] Configurer le flash au niveau de la capture RAW dans `ios/Runner/Camera/RawPhotoCaptureService.swift` selon la capacité découverte (signaler indisponibilité si aucun flash et ne pas tenter d'activation, activer uniquement au déclencheur si disponible, interdire strictement `torchMode` en preview)
- [ ] T020 [US3] Exposer les méthodes de réglages manuels (`setManualIso`, `setManualExposure`, `setManualFocus`, `setFlashMode`) dans `ios/Runner/Camera/CameraBridgePlugin.swift`
- [ ] T021 [P] [US3] Implémenter les curseurs contextuels discrets en surimpression dans `lib/src/ui/manual_controls_overlay.dart` pour l'ISO, la vitesse et le focus
- [ ] T022 [US3] Intégrer le bouton de flash accessible et les surimpressions de réglages manuels dans `lib/src/ui/camera_screen.dart`

**Checkpoint**: Toutes les User Stories sont complètes et fonctionnelles

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Gestion du cycle de vie, robustesse et validation de bout en bout

- [ ] T023 [P] Implémenter les observateurs de cycle de vie de l'application (mise en pause et reprise propre de la caméra) dans `lib/src/ui/camera_screen.dart` et `ios/Runner/Camera/CameraSessionController.swift`
- [ ] T024 [P] Écrire les tests unitaires pour les modèles de données dans `test/camera_models_test.dart` (validation des limites dynamiques de `CameraDeviceInfo`, comportement aux bornes découvertes et rejet des valeurs hors plage, sans valeurs matérielles fixes inventées)
- [ ] T025 Exécuter les 4 scénarios de validation empirique sur iPhone 14 physique décrits dans `specs/001-complete-camera-mvp/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : Aucune dépendance — démarre immédiatement.
- **Foundational (Phase 2)** : Dépend de la Phase 1 — BLOQUE toutes les User Stories.
- **User Story 1 (Phase 3)** : Dépend de la Phase 2 — constitue le MVP.
- **User Story 2 (Phase 4)** : Dépend de la Phase 2 (et intègre le déclencheur de US1).
- **User Story 3 (Phase 5)** : Dépend de la Phase 2 (et enrichit l'écran caméra de US1).
- **Polish (Phase 6)** : Dépend de l'achèvement des User Stories.

### Parallel Opportunities

- Phase 1 : T002 et T003 en parallèle.
- Phase 2 : T004, T005, T006 en parallèle.
- Phase 3 : T008, T010, T011 en parallèle.
- Phase 4 : T014 et T015 en parallèle.
- Phase 5 : T018 et T021 en parallèle.
- Phase 6 : T023 et T024 en parallèle.

---

## Parallel Example: User Story 1

```bash
# Lancement des tâches parallèles pour User Story 1 :
Task: "Implémenter la session caméra native dans ios/Runner/Camera/CameraSessionController.swift"
Task: "Implémenter le widget de rendu ViewfinderWidget dans lib/src/ui/viewfinder_widget.dart"
Task: "Implémenter la barre de capture inférieure dans lib/src/ui/capture_controls_widget.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1)
1. Terminer Setup (Phase 1) et Foundational (Phase 2).
2. Implémenter User Story 1 (Phase 3).
3. **VALIDER** : Lancer l'application sur l'appareil et vérifier le viseur présentant le preview à 24 FPS et l'ergonomie générale.

### Livraison incrémentale
1. Setup + Fondations → Socle validé.
2. User Story 1 → Viseur live 24 FPS (MVP).
3. User Story 2 → Capture Bayer RAW + dématriçage CPU sans JPEG.
4. User Story 3 → Contrôles manuels contextuels et flash strict.
5. Polish → Cycle de vie et validation empirique finale.
