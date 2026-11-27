# Maison Facile

Télécommande de la maison qui tourne **sur le Raspberry Pi 5 et son écran tactile officiel**,
en app native (Python + Qt/QML), sans navigateur.

| Appareil | Comment | Ce que ça fait |
|---|---|---|
| Ampli Denon AVR-X3800H | API HTTP du Denon | Marche/veille, entrée, volume, sourdine |
| WiiM Ultra | API HTTP du WiiM | Préréglages Qobuz, radios, podcasts, pause/stop |
| Lumières Hue | Pont Hue local | Pièces on/off et intensité |
| Stores Somfy | Homey Pro (API locale) | Monter / stop / descendre, un par un ou tous |
| Apple TV | pyatv | Allumer, ouvrir Qobuz, télécommande |

Boutons « un geste » :
- **Préréglage Qobuz / Radio / Podcast** → allume le Denon sur *Media Player* (WiiM) et lance la musique.
- **Apple TV** → Denon sur *CBL/SAT* et Apple TV allumée.
- **Tout éteindre** → WiiM, Apple TV, Denon et lumières (avec confirmation).
- Après 60 s sans toucher : grande horloge, luminosité baissée. Un toucher réveille l'écran.

---

## 1. Installer

Sur le Pi (Raspberry Pi OS **avec bureau**), dans un terminal ou en SSH :

```bash
git clone https://github.com/barlouka/maison-facile.git
cd maison-facile
./install.sh
```

L'installation met en place Qt, l'environnement Python, le démarrage automatique sur
l'écran et la baisse de luminosité au repos.

## 2. Configurer

Le plus simple : l'assistant trouve les appareils sur le réseau, appaire la Hue et
l'Apple TV, récupère les stores et les préréglages Qobuz, puis écrit `config.json`.

```bash
.venv/bin/python configurer.py
```

Pour régler à la main (ou ajouter des radios et podcasts) : `nano config.json`.

- **Denon / WiiM / pont Hue / Homey** : leur adresse IP (idéalement fixée dans la box).
  `max_volume` empêche un volume trop fort. `inputs` indique sur quelle entrée du Denon
  sont branchés l'Apple TV et le WiiM (codes : `SAT/CBL`, `BD`, `DVD`, `GAME`, `MPLAY`, `AUX1`, `TV`…).
- **Préréglages Qobuz** : dans l'app **WiiM Home**, joue une playlist ou un album Qobuz,
  puis enregistre-le comme préréglage (1 à 12). Mets le même numéro dans `"preset"`.
- **Hue** : `.venv/bin/python app.py --pair-hue` (appuie sur le bouton du pont quand demandé),
  copie le `username` obtenu. `--list-hue` liste les pièces ; `"rooms": ["1","3"]` pour en garder certaines.
- **Stores** : app Homey → Réglages → *Clés API* → nouvelle clé (droit Appareils), à mettre dans
  `homey.token`, puis `.venv/bin/python app.py --list-homey` (les stores sont marqués « <- store »).
- **Apple TV** :
  ```bash
  .venv/bin/atvremote scan                        # note l'« Identifier »
  .venv/bin/atvremote --id <ID> --protocol companion pair
  .venv/bin/atvremote --id <ID> --protocol airplay pair
  .venv/bin/atvremote --id <ID> app_list          # identifiant de l'app Qobuz
  ```
- **Radios / podcasts** : vérifie les adresses RTS d'exemple ; un podcast se donne par son flux RSS.

Puis `sudo reboot` : l'app démarre toute seule en plein écran.

## Au quotidien

| Pour… | Commande |
|---|---|
| Écran en paysage (écran tactile 2) | `./paysage.sh` (ou `./paysage.sh 270` si à l'envers) |
| Relancer l'app après un changement de `config.json` | `./lancer.sh` |
| Voir les messages de l'app | `cat ~/.cache/maison-facile.log` |
| Tester dans une fenêtre | `.venv/bin/python app.py --fenetre` |
| Mettre à jour | `git pull` puis `./lancer.sh` |

Options de `config.json` : `idle_seconds` (délai avant l'horloge, 0 = jamais),
`screen_dim_percent` (luminosité au repos), `hide_cursor`, `fullscreen`.

## Organisation du code

- `app.py` — démarrage, commandes d'aide
- `maison/devices.py` — pilotage des appareils (sans interface)
- `maison/backend.py` — pont entre l'interface et les appareils (tout en arrière-plan)
- `maison/icons.py` — icônes dessinées à la volée
- `qml/` — l'interface (Main.qml + composants)
