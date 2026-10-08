# Quickstart & Validation Guide: Complete DaWishCam MVP

## Environnement & Prérequis

- **Développement quotidien** : Peut s'effectuer sur tout poste de travail (y compris Windows) pour l'écriture de l'interface Flutter/Dart, la structure des modèles, les tests unitaires et la logique métier agnostique de la plateforme.
- **Validation matérielle & exécution native** : Nécessite un environnement macOS avec Xcode et un iPhone 14 physique connecté pour compiler les couches Swift, exécuter AVFoundation et mesurer les performances sur l'appareil cible.

## Scénarios de validation empirique

### Scénario 1 : Initialisation, ergonomie inspirée d'iOS et preview 24 FPS
1. Lancer l'application sur l'appareil cible (`flutter run -d <device_id>`).
2. Vérifier que le viseur s'affiche et occupe la majeure partie de l'écran.
3. Vérifier le placement familier du bouton de capture en zone inférieure et l'accessibilité du contrôle du flash.
4. Vérifier que la prévisualisation est rendue à une cadence de 24 FPS, sans réglage de cadence accessible dans l'interface.

### Scénario 2 : Découverte dynamique des capacités et contrôles manuels contextuels
1. Déployer les contrôles contextuels en surimpression pour l'ISO, la vitesse d'obturation et le focus.
2. Vérifier que les curseurs reflètent les plages de valeurs réellement découvertes lors de l'initialisation de l'appareil (sans valeurs codées en dur).
3. Modifier les valeurs : vérifier que les paramètres du capteur s'ajustent sans masquer inutilement le viseur.
4. Fermer la surimpression : le viseur redevient totalement dégagé et conserve les paramètres appliqués.

### Scénario 3 : Disponibilité du flash et prohibition de la torche
1. Vérifier si le flash est détecté comme disponible sur l'appareil/configuration.
2. Si disponible, activer le flash : vérifier qu'AUCUNE lumière continue (torche) ne s'allume pendant le preview.
3. Déclencher une capture : vérifier que le flash s'allume uniquement au moment de la prise de vue.
4. Désactiver le flash et capturer : vérifier l'absence totale d'éclairage.

### Scénario 4 : Capture Bayer RAW, dématriçage CPU et absence de JPEG
1. Vérifier si `isBayerRawSupported` est vrai sur l'appareil.
2. Si non supporté : déclencher la capture et vérifier qu'une erreur explicite `RAW_UNAVAILABLE` est renvoyée, sans création de JPEG.
3. Si supporté : déclencher la capture, vérifier le traitement de dématriçage CPU pour l'aperçu photo, et vérifier dans le stockage de l'application que :
   - Le fichier Bayer RAW brut est correctement persisté avec son intégrité vérifiable ;
   - Aucun fichier JPEG ou HEIF n'a été créé ou persisté.
