# Maison Facile

App iOS (SwiftUI, iOS 17+) toute simple pour piloter la maison :
Denon AVR-X3800H, WiiM Ultra, Apple TV/Qobuz, radio, podcasts, stores Somfy et lumières Hue, via le **Homey Pro**.

## Principe

- **Gros boutons de l'accueil** : chaque bouton lance un **Flow Homey** (ex. « Qobuz », « Apple TV », « Soirée », « Tout éteindre »). Toute la logique reste dans Homey : tu modifies un Flow sans toucher à l'app.
- **Radio / Podcasts** : l'app envoie l'adresse du flux **directement au lecteur** (Denon via HEOS ou WiiM Ultra). L'iPhone peut ensuite être rangé, la lecture continue.
- **Lumières & stores** : liste les appareils Homey (Hue, Somfy) avec allumer/éteindre/variateur et monter/stop/descendre, plus un bouton « Tous les stores ».
- **Volume** : barre en bas, qui pilote le lecteur choisi.

## Mise en route

### 1. Ouvrir le projet
Le projet Xcode est prêt : `MaisonFacile.xcodeproj` (Xcode 16 ou plus récent). Les dossiers `MaisonFacile/`, `Shared/` et `MaisonFacileWidget/` sont synchronisés : tout fichier ajouté dedans est pris en compte automatiquement.

1. Ouvrir `MaisonFacile.xcodeproj`.
2. Cibles **MaisonFacile** et **MaisonFacileWidget** → *Signing & Capabilities* → choisir ton **Team**. Xcode crée les identifiants et le groupe d'apps.
3. Brancher l'iPhone ou l'iPad, choisir le schéma **MaisonFacile**, puis ▶︎.

Déjà réglé dans le projet : iPhone + iPad, iOS 17, réseau local (`Config/*.plist`), App Group `group.ch.barlouka.maisonfacile` (`Config/*.entitlements`), langue de développement français (pour Siri).

### 2. Homey Pro
- App web Homey → **Réglages → Clés API → Nouvelle clé** : cocher au minimum *Flows* (lancer) et *Appareils* (contrôler). Copier la clé.
- Créer un Flow par bouton, qui **commence par la carte « Ce Flow est démarré »** (sinon il ne peut pas être lancé par l'API). Exemples :
  - **Qobuz** : Denon allumé, entrée HEOS/Online Music, volume 35. L'app ouvre ensuite Qobuz → bouton Connect → choisir le Denon (ou le WiiM).
  - **Apple TV** : Denon allumé sur l'entrée CBL/SAT. L'app lance ensuite le raccourci iOS **« Maison Apple TV »** (actions *Réveiller l'Apple TV* + *Afficher la télécommande*), qui allume l'Apple TV et ouvre la télécommande virtuelle d'iOS.
  - **Avant d'écouter** (optionnel, réglage « Flow avant d'écouter ») : allumer le Denon sur l'entrée du WiiM si le WiiM est branché sur l'ampli.
  - **Tout éteindre** : Denon en veille, lumières éteintes.

### 3. Appareils
- Denon : *Configuration → Réseau → Contrôle réseau : Toujours actif*. Mettre des IP fixes (réservation DHCP) au Denon, au WiiM et au Homey.
- Dans l'app : ⚙️ → IP du Homey + clé, IP du Denon / WiiM, choisir le lecteur radio, attribuer un Flow à chaque bouton.
- Les radios proposées (RTS La 1ère, Couleur 3, Option Musique, Espace 2) sont des adresses SRG SSR **à vérifier**. Les podcasts s'ajoutent avec leur adresse RSS.

## Widgets et Siri

### Ce que ça donne
- **Widget Maison** (petit, moyen, grand) : les boutons de l'accueil, les radios favorites, pause/lecture et volume, utilisables directement depuis l'écran d'accueil, sans ouvrir l'app.
- **Écran verrouillé** : un bouton rond « Pause musique ».
- **Siri** : « Dis Siri, Soirée avec Maison Facile », « Dis Siri, mets Couleur 3 avec Maison Facile », « Dis Siri, pause avec Maison Facile ». Les mêmes actions sont dans l'app Raccourcis (automatisations possibles).

Les réglages sont maintenant stockés dans le groupe d'apps ; les anciens réglages sont relus automatiquement la première fois.

## En cours de lecture
La barre du bas affiche le titre, l'artiste et la pochette (Denon via HEOS, WiiM via son API), mis à jour toutes les 5 secondes. L'horloge au repos de l'iPad affiche aussi le morceau en cours.

## Sur iPad (télécommande du salon)
- Dans Xcode, cible → *General → Supported Destinations* : ajouter **iPad**.
- Sur iPad, l'accueil affiche une grande grille de boutons, avec les stores et lumières toujours visibles à droite.
- Réglages de l'app → **Mode télécommande** : l'écran ne se met plus en veille (iPad branché sur son support).
- **Horloge au repos** : après un délai sans toucher l'écran (30 s à 5 min), l'iPad affiche l'heure façon Apple Watch (grands chiffres ou aiguilles), fond noir, luminosité basse. Un toucher le réveille et rétablit la luminosité. L'horloge bouge un peu chaque minute pour ménager l'écran.
- **La nuit (23 h – 6 h)**, si l'option est active, l'iPad se met en veille normalement pour économiser l'énergie.
- Pour bloquer l'iPad sur l'app : Réglages iPad → Accessibilité → **Accès guidé**, puis triple-clic sur le bouton latéral.

## Structure

```
MaisonFacile/
├── MaisonFacileApp.swift, Assets.xcassets
Shared/        (app + widget) Config, HomeyClient, HeosClient (Denon, TCP 1255),
│              WiimClient (API LinkPlay), AudioPlayer, Intents (widgets/Siri)
├── Models/    AppModel (état + actions)
├── Services/  PodcastService (RSS), IdleController (repos iPad), Shortcuts (Siri)
└── Views/     Accueil, Radio, Podcasts, Lumières & stores, Réglages, Horloge
MaisonFacileWidget/  Widget Maison + bouton pause écran verrouillé
```

## Pistes suivantes
- Mettre la clé API dans le Trousseau (Keychain) plutôt que dans UserDefaults.
- Widgets et Raccourcis (App Intents) pour lancer « Radio » ou « Tout éteindre » depuis l'écran verrouillé.
