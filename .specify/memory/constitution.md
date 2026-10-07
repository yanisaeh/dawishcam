<!--
Sync Impact Report
------------------
Version change: Initial Adoption -> 1.0.0
List of modified principles:
  - PRINCIPLE_1_NAME -> I. Experimental & Empirically Verified Capabilities (NON-NEGOTIABLE)
  - PRINCIPLE_2_NAME -> II. Architectural Decoupling: Flutter UI, Native Swift & Processing Layers
  - PRINCIPLE_3_NAME -> III. RAW-Only Capture & Strict Minimal Processing Pipeline
  - PRINCIPLE_4_NAME -> IV. Pragmatic Performance & Measurement-Driven GPU Adoption
  - PRINCIPLE_5_NAME -> V. Minimal Manual Controls & Strict Flash Behavior
Added sections:
  - Technical Stack & Hardware Boundaries
  - Development Workflow & Quality Gates
Removed sections: None
Follow-up TODOs: None
-->

# DaWishCam Constitution

## Core Principles

### I. Experimental & Empirically Verified Capabilities (NON-NEGOTIABLE)

Hardware and software capabilities of the iPhone 14 and AVFoundation MUST be proven experimentally before technical choices are considered established:

- Hardware, sensor, or API capabilities that have not been experimentally verified on physical hardware MUST NOT be considered available.
- Every architectural assumption regarding Bayer RAW capture formats, manual parameter ranges, and pipeline throughput MUST be validated through targeted device tests.
- Design choices MUST adapt to observed device behavior rather than theoretical API documentation.
  _Rationale_: AVFoundation hardware abstractions and sensor capabilities vary across iPhone models. Building on unverified assumptions risks late-stage architectural failures.

### II. Architectural Decoupling: Flutter UI, Native Swift & Processing Layers

The system architecture MUST enforce strict boundaries between five distinct subsystems:

- **Flutter UI**: Responsible exclusively for presentation, controls display, and high-level application flow.
- **Bridge Layer**: Platform interface (Method/Event Channels, Pigeon, or FFI) facilitating typed, decoupled communication between Dart and native code.
- **Native Camera Layer**: Swift implementation interfacing directly with AVFoundation (`AVCaptureSession`, `AVCaptureDevice`).
- **RAW Capture Layer**: Native logic dedicated strictly to acquiring uncompressed raw sensor buffers.
- **RAW Processing Pipeline**: Dedicated image processing pipeline operating independently of the camera lifecycle.
  _Rationale_: Strict separation isolates native AVFoundation lifecycle subtleties from cross-platform UI state, keeping the experimental codebase modular and maintainable.

### III. RAW-Only Capture & Strict Minimal Processing Pipeline

The capture and processing pipeline MUST remain minimal, direct, and unencumbered by post-processing:

- Still captures MUST be acquired in Bayer RAW when hardware and AVFoundation permit.
- The MVP MUST NOT generate or persist JPEG images.
- The minimal processing pipeline is strictly defined as: `Bayer RAW → Demosaicing → RGB → Preview at 24 FPS`.
- The live preview MUST be rendered at 24 FPS. Sensor FPS MUST NOT be exposed as a user-configurable setting.
- Custom white balance, advanced colorimetric transformations, custom Log curves, noise reduction, sharpening, and HDR are strictly excluded from the MVP.
  _Rationale_: Preserves raw sensor fidelity, simplifies debugging, and avoids premature complexity in color science before basic capture and demosaicing are solid.

### IV. Pragmatic Performance & Measurement-Driven GPU Adoption

Algorithmic correctness on CPU strictly precedes GPU acceleration:

- Demosaicing and image conversion algorithms MUST first have a correct, verified CPU implementation.
- Metal / GPU compute shaders MUST ONLY be introduced when empirical performance profiling demonstrates an explicit necessity.
- Optimization efforts MUST be guided by reproducible performance benchmarks, not premature speculation.
  _Rationale_: A correct CPU baseline provides an indisputable reference for numerical correctness, image quality, and benchmarking before introducing shader complexity.

### V. Minimal Manual Controls & Strict Flash Behavior

The MVP remains strictly scoped to essential manual photographic controls:

- User controls are limited to manual ISO, manual shutter speed (exposure duration), manual focus, and a flash toggle.
- Flash illumination rules MUST be strictly respected:
  - When flash is enabled: the flash MUST fire ONLY during still photography capture and MUST NEVER act as continuous illumination (torch) during preview.
  - When flash is disabled: no flash activation of any kind may occur during capture.
- No out-of-scope camera features or secondary settings may be added to the MVP.
  _Rationale_: Keeps the experimental scope tightly focused on core manual camera mechanics without scope creep.

## Technical Stack & Hardware Boundaries

The project standardizes on the following technologies, constraints, and platform scope:

- **Target Platform**: Apple iOS on iPhone 14.
- **Application Layer**: Flutter / Dart managing interface layout and high-level application state.
- **Camera Subsystem**: Swift utilizing AVFoundation (`AVCaptureDeviceInput`, `AVCapturePhotoOutput` with RAW capture settings).
- **Processing Engine**: CPU-first demosaicing (pure Swift / C++), deferring Metal until demonstrated necessary.
- **Preview Cadence**: Fixed 24 FPS preview display pipeline.

## Development Workflow & Quality Gates

Development follows an incremental, empirical lifecycle:

- **Incremental Evolution**: Features MUST be delivered in small, measurable increments consistent with project specifications and verified on device.
- **Commit Standards**: All commits MUST adhere to the Conventional Commits specification (`feat:`, `fix:`, `docs:`, `refactor:`, `perf:`, `test:`, `chore:`).

## Governance

This Constitution is the authoritative engineering reference for DaWishCam.

Implementations and specifications MUST remain consistent with these principles and the defined MVP scope.

Any change to the Constitution MUST be justified by project requirements, verified technical findings, or necessary clarification of existing principles.

The Constitution uses semantic versioning:

- MAJOR: Foundational architectural or governance changes.
- MINOR: Addition or expansion of project principles.
- PATCH: Clarifications and non-semantic corrections.

**Version**: 1.0.0 | **Ratified**: 2026-10-08 | **Last Amended**: 2026-10-08
