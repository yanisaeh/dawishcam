# Contract: Camera Platform Bridge

**Channel Name**: `com.dawishcam/camera`
**Event Channel Name**: `com.dawishcam/camera_events`

## MethodChannel Methods (Flutter → Native iOS)

### `initializeCamera()`
Découvre dynamiquement les capacités de l'appareil et initialise le flux de prévisualisation.
- **Entrée** : aucune.
- **Sortie** : `Map<String, dynamic>` avec les valeurs réelles découvertes (placeholders ci-dessous) :
  ```json
  {
    "textureId": "<int: registered_texture_id>",
    "isBayerRawSupported": "<bool: true_if_bayer_raw_verified>",
    "detectedRawPixelFormat": "<int?: discovered_fourcc_code_or_null>",
    "hasFlash": "<bool: device_has_flash>",
    "minIso": "<double?: discovered_active_format_min_iso>",
    "maxIso": "<double?: discovered_active_format_max_iso>",
    "minExposureDurationSeconds": "<double?: discovered_active_format_min_duration>",
    "maxExposureDurationSeconds": "<double?: discovered_active_format_max_duration>",
    "isFocusLockSupported": "<bool: locking_focus_supported>"
  }
  ```

### `setManualIso(double iso)`
- Applique la sensibilité ISO spécifiée (doit être comprise dans l'intervalle découvert `[minIso, maxIso]`).

### `setManualExposure(double durationSeconds)`
- Applique la durée d'exposition (doit être comprise dans l'intervalle découvert `[minExposureDurationSeconds, maxExposureDurationSeconds]`).

### `setManualFocus(double lensPosition)`
- Règle la position de la lentille (plage normalisée `[0.0, 1.0]`).

### `setFlashMode(bool enabled)`
- Active ou désactive le flash pour la capture.
- Si `hasFlash == false`, renvoie une erreur `FLASH_UNAVAILABLE`.

### `captureBayerRaw()`
- Déclenche la capture photo Bayer RAW si la capacité a été expérimentalement vérifiée.
- **Comportement si RAW non disponible** :
  - Lève une exception `PlatformException(code: "RAW_UNAVAILABLE", message: "Bayer RAW capture is not supported on this device/configuration")`.
  - Aucun fichier JPEG ou HEIF n'est généré ni stocké.
- **Comportement si RAW disponible** :
  - Acquiert le buffer Bayer RAW, persiste le fichier dans le stockage de l'application, et transmet les métadonnées de résultat (sans transporter de gros buffer RGB dans le message) :
  ```json
  {
    "captureId": "<string: unique_capture_identifier>",
    "rawFilePath": "<string: persisted_file_path>",
    "rawPixelFormat": "<int: verified_fourcc_code>",
    "byteCount": "<int: actual_raw_byte_count>",
    "status": "completed"
  }
  ```

### `pausePreview()` / `resumePreview()`
- Met en pause ou réactive la session de prévisualisation lors des cycles de vie de l'application.

## EventChannel Events (Native iOS → Flutter)

Événements d'état et de cycle de vie sur `com.dawishcam/camera_events` :
```json
{
  "event": "captureStateChanged",
  "state": "capturing" | "persisting" | "demosaicing" | "completed" | "failed",
  "errorCode": "<string?: optional_error_code>",
  "message": "<string?: diagnostic_message>"
}
```
