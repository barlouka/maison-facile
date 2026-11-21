# Maison Facile

App iOS (SwiftUI, iOS 17+) toute simple pour piloter la maison :
Denon AVR-X3800H, WiiM Ultra, Apple TV/Qobuz, radio, podcasts, stores Somfy et lumières Hue, via le **Homey Pro**.

## Principe

- **Gros boutons de l'accueil** : chaque bouton lance un **Flow Homey** (ex. « Qobuz », « Apple TV », « Soirée », « Tout éteindre »). Toute la logique reste dans Homey : tu modifies un Flow sans toucher à l'app.
- **Radio / Podcasts** : l'app envoie l'adresse du flux **directement au lecteur** (Denon via HEOS ou WiiM Ultra). L'iPhone peut ensuite être rangé, la lecture continue.
- **Lumières & stores** : liste les appareils Homey (Hue, Somfy) avec allumer/éteindre/variateur et monter/stop/descendre, plus un bouton « Tous les stores ».
- **Volume** : barre en bas, qui pilote le lecteur choisi.

## Mise en route

### 1. Créer le projet Xcode
1. Xcode → *New Project* → iOS **App**, nom `MaisonFacile`, interface SwiftUI, iOS 17 minimum.
2. Supprimer `ContentView.swift` et le fichier `MaisonFacileApp.swift` généré.
3. Glisser le dossier `MaisonFacile/` (Models, Services, Views, MaisonFacileApp.swift) dans le projet (« Create groups »).
4. Onglet **Info** de la cible, ajouter :
   - `Privacy - Local Network Usage Description` (NSLocalNetworkUsageDescription) : « Pour piloter l'ampli, le WiiM et le Homey de la maison. »
   - `App Transport Security Settings` → `Allow Local Networking` = YES (NSAllowsLocalNetworking).

   (Le fichier `Info-additions.plist` contient ces clés à copier.)

### 2. Homey Pro
- App web Homey → **Réglages → Clés API → Nouvelle clé** : cocher au minimum *Flows* (lancer) et *Appareils* (contrôler). Copier la clé.
- Créer un Flow par bouton, qui **commence par la carte « Ce Flow est démarré »** (sinon il ne peut pas être lancé par l'API). Exemples :
  - **Qobuz** : Denon allumé, entrée HEOS/Online Music, volume 35. L'app ouvre ensuite Qobuz → bouton Connect → choisir le Denon (ou le WiiM).
  - **Apple TV** : Denon allumé sur l'entrée de l'Apple TV + réveil de l'Apple TV.
  - **Avant d'écouter** (optionnel, réglage « Flow avant d'écouter ») : allumer le Denon sur l'entrée du WiiM si le WiiM est branché sur l'ampli.
  - **Tout éteindre** : Denon en veille, lumières éteintes.

### 3. Appareils
- Denon : *Configuration → Réseau → Contrôle réseau : Toujours actif*. Mettre des IP fixes (réservation DHCP) au Denon, au WiiM et au Homey.
- Dans l'app : ⚙️ → IP du Homey + clé, IP du Denon / WiiM, choisir le lecteur radio, attribuer un Flow à chaque bouton.
- Les radios proposées (RTS La 1ère, Couleur 3, Option Musique, Espace 2) sont des adresses SRG SSR **à vérifier**. Les podcasts s'ajoutent avec leur adresse RSS.

## Structure

```
MaisonFacile/
├── MaisonFacileApp.swift
├── Models/    Config (réglages sauvegardés), AppModel (état + actions)
├── Services/  HomeyClient (API locale), HeosClient (Denon, TCP 1255),
│              WiimClient (API HTTP LinkPlay), PodcastService (RSS)
└── Views/     Accueil, Radio, Podcasts, Lumières & stores, Réglages
```

## Pistes suivantes
- Mettre la clé API dans le Trousseau (Keychain) plutôt que dans UserDefaults.
- Widgets et Raccourcis (App Intents) pour lancer « Radio » ou « Tout éteindre » depuis l'écran verrouillé.
- Afficher le titre en cours (HEOS `get_now_playing_media`, WiiM `getPlayerStatus`).
- Version Apple TV / iPad en mode « télécommande ».
