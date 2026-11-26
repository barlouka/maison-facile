# Maison Facile — télécommande de la maison sur Raspberry Pi 5

Une page web aux gros boutons, installée sur l'écran d'accueil de l'iPhone ou de l'iPad,
qui pilote :

| Appareil | Comment | Ce que ça fait |
|---|---|---|
| Ampli Denon AVR-X3800H | API HTTP du Denon | Marche/veille, entrée, volume, sourdine |
| WiiM Ultra | API HTTP du WiiM | Préréglages Qobuz, radios, podcasts, pause/stop |
| Lumières Hue | Pont Hue local | Pièces on/off et intensité |
| Stores Somfy | Homey Pro (API locale) | Monter / stop / descendre, ou tous ensemble |
| Apple TV | pyatv | Allumer, ouvrir Qobuz, télécommande |

Boutons « un geste » :
- **Préréglage Qobuz / Radio / Podcast** → allume le Denon, le met sur *Media Player* (WiiM), lance la musique.
- **Apple TV** → allume le Denon sur *CBL/SAT*, allume l'Apple TV.
- **Tout éteindre** → WiiM, Apple TV, Denon et lumières.
- Sur iPad, après 60 s sans contact : grande horloge sur fond noir. Un toucher la réveille.

---

## 1. Installation sur le Pi

```bash
# Copier le dossier sur le Pi (depuis le Mac)
scp -r maison-facile-pi pi@raspberrypi.local:~/

# Sur le Pi
cd ~/maison-facile-pi
chmod +x install.sh
./install.sh
```

Le service démarre tout seul à chaque allumage du Pi.
Commandes utiles : `sudo systemctl restart maison-facile`, `journalctl -u maison-facile -f`.

> Conseil : donne une **IP fixe** (réservation DHCP dans la box) au Pi, au Denon, au WiiM,
> au pont Hue, au Homey et à l'Apple TV.

## 2. Remplir `config.json`

Toutes les commandes ci-dessous se lancent dans `~/maison-facile-pi` :

**Denon / WiiM** : mets simplement leur adresse IP. `max_volume` empêche un volume trop fort.

**Préréglages Qobuz** : dans l'app **WiiM Home**, joue une playlist ou un album Qobuz, puis
appui long sur le bouton de préréglage pour l'enregistrer (1 à 12). Dans `config.json`, mets
le même numéro dans `"preset"` et un nom lisible.

**Hue** :
```bash
.venv/bin/python server.py --pair-hue   # appuie sur le bouton du pont quand demandé
.venv/bin/python server.py --list-hue   # (optionnel) liste les pièces
```
Copie le `username` obtenu dans `hue.username`. Pour n'afficher que certaines pièces,
ajoute `"rooms": ["1", "3"]`.

**Homey (stores)** : dans l'app Homey → Réglages → *Clés API* → nouvelle clé avec le droit
« Appareils » (contrôle). Mets-la dans `homey.token`, puis :
```bash
.venv/bin/python server.py --list-homey  # les stores sont marqués « <- store »
```

**Apple TV** :
```bash
.venv/bin/atvremote scan                       # note l'« Identifier »
.venv/bin/atvremote --id <IDENTIFIER> --protocol companion pair
.venv/bin/atvremote --id <IDENTIFIER> --protocol airplay pair
.venv/bin/atvremote --id <IDENTIFIER> app_list # cherche Qobuz, copie son identifiant
```
Un code s'affiche sur la TV à chaque appairage. Les identifiants sont mémorisés par pyatv.

**Radios** : les adresses RTS fournies sont un point de départ. Vérifie-les, et ajoute
n'importe quel flux MP3/AAC. **Podcasts** : l'adresse du flux RSS (Apple Podcasts →
« Copier le lien » ne suffit pas ; un site comme getrssfeed.com donne le vrai flux).

Après chaque modification : `sudo systemctl restart maison-facile`.

## 3. Sur l'iPhone / l'iPad

Safari → `http://raspberrypi.local:8000` → bouton Partager → **Sur l'écran d'accueil**.
L'app s'ouvre alors en plein écran, sans barre Safari.

Pour l'iPad du salon : Réglages → Luminosité → Verrouillage auto → *Jamais*, et
Accès guidé (Accessibilité) pour bloquer l'iPad sur l'app si tu veux.

## Bon à savoir

- Tout reste à la maison : rien ne passe par Internet (sauf la musique elle-même).
- Pas de mot de passe : l'app n'est accessible que depuis ton Wi-Fi. Ne l'ouvre pas sur Internet.
- Le serveur n'utilise que Python standard ; seule l'Apple TV a besoin de `pyatv`.
  Sans elle, le reste fonctionne.
- Si l'app Denon de Homey est aussi installée, pas de conflit : on passe par HTTP, pas par telnet.
