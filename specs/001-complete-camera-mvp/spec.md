# Feature Specification: Complete DaWishCam MVP

**Feature Branch**: `001-complete-camera-mvp`

**Created**: 2026-10-08

**Status**: Draft

**Input**: User description: "Complete DaWishCam MVP (24 FPS Preview, Manual Controls, and Bayer RAW Still Capture)"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Live Viewfinder Preview at 24 FPS & iOS-Familiar Layout (Priority: P1)

As a photographer, I want to open DaWishCam and immediately view a live camera viewfinder rendered at 24 frames per second in an interface familiar to iOS camera users, where the viewfinder occupies the dominant area of the screen with a bottom-anchored shutter button and an accessible flash toggle, so that I can compose and frame my scenes intuitively without visual distraction.

**Why this priority**: The live viewfinder preview is the foundational capability of the camera application. Combining a steady 24 FPS stream with an intuitive, viewfinder-centric layout gives the photographer immediate visual feedback and effortless composition.

**Independent Test**: Can be verified on a target device; launching the application displays the live camera stream rendered at 24 FPS occupying the majority of the screen, with the shutter button positioned in the lower interaction zone.

**Acceptance Scenarios**:

1. **Given** camera permissions are granted, **When** the app is launched, **Then** the camera initializes and displays the live viewfinder feed rendered at 24 frames per second.
2. **Given** the app is active, **When** viewing the screen layout, **Then** the viewfinder occupies the dominant portion of the screen, and the primary shutter capture button is positioned in the lower interaction zone following familiar iOS camera conventions.
3. **Given** the live viewfinder preview is active, **When** the user views the stream, **Then** the preview is rendered at a target cadence of 24 FPS.
4. **Given** the app is running, **When** inspecting available settings, **Then** the preview frame rate is fixed at 24 FPS and sensor FPS is not exposed as a user-configurable setting.

---

### User Story 2 - Bayer RAW Still Capture & Minimal Processing (Priority: P2)

As a photographer, I want to trigger still capture to acquire a Bayer RAW photograph when supported by the hardware and AVFoundation, and see an RGB preview produced by a minimal demosaicing pipeline, so that I obtain uncompressed sensor data without JPEG generation.

**Why this priority**: Bayer RAW capture is the core focus of DaWishCam. The minimal pipeline ensures raw sensor acquisition without automated JPEG conversion or post-processing.

**Independent Test**: Can be verified by triggering capture; when Bayer RAW capture is experimentally verified on hardware and AVFoundation, the app acquires the raw sensor buffer, runs minimal CPU demosaicing to produce an RGB preview, and persists the raw capture with zero JPEG files created.

**Acceptance Scenarios**:

1. **Given** the live preview is active, **When** the user triggers still capture, **Then** the system requests and acquires a Bayer RAW buffer if supported by the device hardware and AVFoundation.
2. **Given** a Bayer RAW capture is acquired, **When** processing takes place, **Then** the raw data is converted to an RGB preview via a minimal CPU-first demosaicing pipeline (Bayer RAW → Demosaicing → RGB) without noise reduction, sharpening, HDR, custom colorimetric curves, or custom white balance.
3. **Given** the capture process completes, **When** persistent storage is inspected, **Then** the raw capture is persisted and no JPEG image is generated or stored.
4. **Given** capture is triggered, **When** capture is underway, **Then** visual feedback indicates capture progress and confirms completion.

---

### User Story 3 - Essential Manual Photographic Controls & Flash (Priority: P3)

As a photographer, I want to manually adjust ISO, shutter speed (exposure duration), lens focus position, and flash mode through discrete, non-intrusive controls integrated into the camera experience, so that I maintain manual creative authority over exposure parameters without transforming the screen into a permanent settings panel or obscuring the viewfinder.

**Why this priority**: Essential manual controls turn the camera into a deliberate photographic instrument while preserving an uncluttered viewfinder experience.

**Independent Test**: Can be verified by adjusting ISO, shutter speed, focus controls, and toggling flash; the preview and captures reflect the manual adjustments within the device's experimentally verified operational ranges, and the controls can be adjusted without hiding the framed subject.

**Acceptance Scenarios**:

1. **Given** the viewfinder is active, **When** the user views the camera interface, **Then** the flash control is readily accessible as an unobtrusive overlay control.
2. **Given** the user wishes to adjust exposure or focus parameters, **When** invoking manual controls, **Then** ISO, shutter speed, and focus controls appear as discrete, contextual overlays that do not permanently replace the viewfinder with a settings panel.
3. **Given** manual controls are adjusted, **When** the user adjusts ISO, shutter speed, or focus sliders, **Then** the sensor parameters update in real-time according to experimentally verified hardware ranges while keeping the viewfinder visible.
4. **Given** the flash toggle is enabled, **When** still capture is triggered, **Then** the flash fires strictly during the still capture and never functions as a continuous torch during the live preview.
5. **Given** the flash toggle is disabled, **When** still capture is triggered, **Then** no flash illumination occurs during preview or capture.

---

### Edge Cases

- What happens when camera permissions are denied by the user? The application displays a clear permission explanation screen and provides a direct shortcut to system settings without crashing.
- What happens when available device storage cannot accommodate capture? The app safely notifies the user of insufficient storage and handles write failure gracefully.
- What happens when the app moves to the background during an active preview or capture? The camera session pauses cleanly, releases hardware locks, and resumes the 24 FPS preview upon returning to the foreground without leaking resources.
- What happens if Bayer RAW capture is not supported by the hardware or AVFoundation configuration? The system reports that the Bayer RAW capability is unavailable on the current device configuration rather than silently failing or falling back to JPEG.
- What happens when a user triggers capture repeatedly in quick succession? The system queues or throttles capture requests to prevent buffer exhaustion until the preceding capture completes.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST initialize native camera hardware and render the live viewfinder preview at a fixed 24 FPS.
- **FR-002**: System MUST NOT expose sensor FPS as a user-configurable parameter in the interface.
- **FR-003**: System MUST acquire still captures in Bayer RAW format when Bayer RAW capture is supported by the iPhone 14 hardware and AVFoundation, with that capability experimentally verified on the target device.
- **FR-004**: System MUST NOT generate, compress, or persist JPEG images for still captures or previews.
- **FR-005**: System MUST implement a minimal RAW processing pipeline strictly defined as: Bayer RAW → CPU Demosaicing → RGB → Preview.
- **FR-006**: System MUST exclude automated noise reduction, sharpening, HDR, custom colorimetric curves, and custom white balance from the MVP pipeline.
- **FR-007**: System MUST allow manual adjustment of ISO sensitivity within experimentally verified hardware ranges.
- **FR-008**: System MUST allow manual adjustment of exposure duration (shutter speed) within experimentally verified hardware ranges.
- **FR-009**: System MUST allow manual adjustment of lens focus position within experimentally verified hardware ranges.
- **FR-010**: System MUST provide a flash toggle control with binary states (enabled / disabled).
- **FR-011**: When flash is enabled, system MUST trigger the flash strictly during still photo capture and MUST NEVER illuminate as continuous torch light during the live preview.
- **FR-012**: When flash is disabled, system MUST completely suppress all flash illumination during preview and capture.
- **FR-013**: System MUST enforce architectural decoupling between Flutter UI, Bridge Layer, Native Camera Layer, RAW Capture Layer, and RAW Processing Pipeline.
- **FR-014**: System MUST persist acquired raw captures to storage with verifiable data integrity.
- **FR-015**: System MUST provide visual feedback during still capture to notify the user of capture initiation and completion.
- **FR-016**: The user interface MUST strongly draw inspiration from the native iOS Camera application experience and interaction conventions while remaining a distinct DaWishCam interface.
- **FR-017**: The live viewfinder MUST occupy the dominant portion of the screen display area.
- **FR-018**: The primary shutter capture button MUST be positioned in the lower interaction zone of the screen, following familiar iOS camera application layout.
- **FR-019**: The flash toggle control MUST be readily accessible directly on the primary camera screen.
- **FR-020**: Manual controls (ISO, shutter speed, focus) MUST be integrated as discrete, contextual overlays that do not transform the screen into a permanent settings panel or unnecessarily obscure the viewfinder.

### Key Entities *(include if feature involves data)*

- **Camera Control State**: Encapsulates manual photographic parameters including target ISO value, target exposure duration, lens position value, binary flash enablement state, and active manual control overlay state, bounded by experimentally validated ranges.
- **Viewfinder Frame**: Represents a single RGB frame buffer rendered in the presentation UI at a target 24 FPS cadence.
- **Bayer RAW Capture**: Represents an uncompressed sensor raw buffer and metadata acquired upon capture, persisted to storage and demosaiced on CPU for preview.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The live viewfinder preview renders at a target cadence of 24 frames per second.
- **SC-002**: When Bayer RAW capture is supported by hardware and AVFoundation, 100% of acquired still captures are persisted strictly as raw sensor data with zero JPEG files generated or stored.
- **SC-003**: Acquired Bayer RAW captures are processed to an RGB preview through the CPU demosaicing pipeline without relying on GPU/Metal acceleration.
- **SC-004**: Manual ISO, exposure duration, and focus adjustments modify native camera device parameters within experimentally verified ranges.
- **SC-005**: In flash-enabled captures, the flash illuminates exclusively at the capture instant with zero torch illumination during viewfinder preview.
- **SC-006**: The system cleanly handles lifecycle transitions (backgrounding, foregrounding, capture initiation, capture completion) without application crashes.
- **SC-007**: The viewfinder remains unobstructed as the dominant visual element across all shooting states, with manual controls accessible as overlays without navigating away from the camera screen.

## Assumptions

- **Target Device & Hardware**: Target platform is Apple iOS on iPhone 14 with AVFoundation.
- **Empirical Validation**: In accordance with Constitution Principle I, hardware and sensor capabilities (Bayer RAW formats, manual parameter ranges, buffer throughput) are subject to empirical verification on physical hardware.
- **Minimalist MVP Scope**: Advanced computational photography (multi-frame exposure blending, deep fusion, semantic rendering, night mode) is strictly excluded to preserve raw sensor purity.
- **Fixed Preview Cadence**: The 24 FPS preview cadence is an architectural standard for DaWishCam and will remain invariant.
- **CPU-First Processing**: In accordance with Constitution Principle IV, demosaicing algorithms are initially implemented and verified on the CPU before introducing Metal/GPU compute shaders.
- **Storage Management**: Raw capture storage location will be determined in accordance with platform file system permissions and sandboxing requirements.
- **UI/UX Paradigm**: Native iOS camera conventions guide the visual hierarchy and ergonomics (bottom shutter button, unobtrusive overlays, dominant viewfinder) without replicating proprietary iOS features outside the MVP scope.
