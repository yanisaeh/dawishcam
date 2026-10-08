# Implementation Plan: Complete DaWishCam MVP

**Branch**: `001-complete-camera-mvp` | **Date**: 2026-10-08 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-complete-camera-mvp/spec.md`

## Summary

Implémenter le MVP DaWishCam complet en respectant les 5 principes de la Constitution :
- Interface Flutter inspirée de l'ergonomie iOS (viseur dominant, bouton de capture en zone inférieure, flash accessible, réglages manuels ISO/vitesse/focus en surimpressions contextuelles discrètes) ;
- Séparation stricte en 5 sous-systèmes : Flutter UI, Bridge Layer, Native Camera Layer, RAW Capture Layer, RAW Processing Pipeline ;
- Découverte expérimentale obligatoire des capacités de l'iPhone 14 (formats Bayer RAW via `isBayerRAWPixelFormat(_:)`, plages ISO/vitesse/focus réelles, présence du flash) sans aucune valeur présumée ;
- Viseur en direct régulé à 24 FPS via le flux vidéo natif et `FlutterTexture` (mécanisme candidat dont le comportement mémoire et les copies seront mesurés sur l'appareil) ;
- Capture photo Bayer RAW exclusive lorsque disponible (aucun JPEG/HEIF en fallback) et pipeline minimal de dématriçage bilinéaire sur CPU pour l'aperçu photo capturée ;
- Règle stricte du flash : actif uniquement au déclenchement, `torchMode` strictement interdit en continu pendant la prévisualisation.

## Technical Context

**Language/Version**: Dart ^3.13 (Flutter SDK) + Swift (iOS 16+, AVFoundation).

**Primary Dependencies**: Flutter framework, `FlutterTextureRegistry`, `AVFoundation` natif.

**Storage**: Persistance du buffer de données brutes Bayer RAW dans l'espace de stockage de l'application (sans génération de JPEG ou HEIF).

**Testing**: Tests unitaires Flutter pour la logique des contrôles et du bridge ; validation empirique sur appareil physique iPhone 14 pour AVFoundation, la cadence 24 FPS et le dématriçage CPU.

**Target Platform**: Apple iOS sur iPhone 14 physique (développement cross-platform Flutter possible sous Windows).

**Project Type**: Application mobile (Flutter + couche native Swift).

**Performance Goals**: Rendu du viseur régulé à une cadence de 24 FPS ; mesures expérimentales sur appareil des copies de buffers éventuelles et du comportement mémoire.

**Constraints**:
- Dématriçage CPU uniquement pour la photo capturée (pas d'accélération GPU/Metal tant que non justifiée par des mesures) ;
- Aucune courbe de virage, HDR, réduction de bruit ou accentuation ;
- Zéro JPEG/HEIF ;
- Viseur toujours dominant et non obstrué de façon permanente.

**Scale/Scope**: Périmètre MVP strictement délimité aux 4 contrôles manuels, au viseur 24 FPS, et à la capture Bayer RAW avec dématriçage CPU.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Principle I: Experimental & Empirically Verified Capabilities** : **PASS**. Aucune capacité (Bayer RAW, plages de paramètres, flash) n'est présumée. Découverte dynamique via l'API AVFoundation (`isBayerRAWPixelFormat(_:)`, `activeFormat`).
- **Principle II: Architectural Decoupling** : **PASS**. Découplage strict entre Flutter UI, Bridge Layer (`MethodChannel`/`EventChannel`), Native Camera Layer, RAW Capture Layer et RAW Processing Pipeline.
- **Principle III: RAW-Only Capture & Strict Minimal Processing Pipeline** : **PASS**. Capture RAW exclusive sans JPEG/HEIF. Pipeline minimal `Bayer RAW → Dématriçage CPU → RGB` dédié à la capture photo. Viseur 24 FPS distinct et sans réglage de framerate exposé.
- **Principle IV: Pragmatic Performance & Measurement-Driven GPU Adoption** : **PASS**. Algorithme de dématriçage bilinéaire implémenté sur CPU. Évaluation Metal reportée jusqu'à preuve de nécessité par profilage.
- **Principle V: Minimal Manual Controls & Strict Flash Behavior** : **PASS**. Contrôles limités à ISO, vitesse, focus et flash. Flash actif uniquement au déclenchement, mode torche strictement interdit pendant le preview.

## Project Structure

### Documentation (this feature)

```text
specs/001-complete-camera-mvp/
├── spec.md              # Feature specification
├── plan.md              # Implementation plan
├── research.md          # Phase 0 technical research
├── data-model.md        # Phase 1 data entities and rules
├── quickstart.md        # Phase 1 validation scenarios
├── contracts/           # Phase 1 interface contracts
│   └── camera-channel.md
├── checklists/
│   └── requirements.md  # Quality checklist
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/
├── main.dart
└── src/
    ├── bridge/
    │   ├── camera_bridge.dart
    │   └── camera_models.dart
    └── ui/
        ├── camera_screen.dart
        ├── viewfinder_widget.dart
        ├── capture_controls_widget.dart
        └── manual_controls_overlay.dart

ios/Runner/
├── AppDelegate.swift
└── Camera/
    ├── CameraBridgePlugin.swift
    ├── CameraSessionController.swift
    ├── RawPhotoCaptureService.swift
    └── CpuBilinearDemosaicer.swift
```

**Structure Decision**: Architecture mobile hybride découplée respectant les 5 couches constitutionnelles : code de présentation et widgets UI sous `lib/src/ui/`, abstraction du bridge sous `lib/src/bridge/`, et services natifs spécialisés sous `ios/Runner/Camera/`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| *Aucune* | *N/A* | *Conforme à tous les principes sans dérogation* |
