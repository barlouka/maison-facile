#!/usr/bin/env bash
# Installe Maison Facile sur le Raspberry Pi (Raspberry Pi OS avec bureau).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"

echo "→ Paquets Qt (interface native)…"
sudo apt-get update
sudo apt-get install -y python3-venv avahi-utils qt6-wayland fonts-inter \
  qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-shapes \
  || true
QT_OK=1
sudo apt-get install -y python3-pyside6.qtcore python3-pyside6.qtgui python3-pyside6.qtqml \
  python3-pyside6.qtquick python3-pyside6.qtsvg || QT_OK=0

echo "→ Environnement Python…"
python3 -m venv --system-site-packages "$DIR/.venv"
"$DIR/.venv/bin/pip" install --upgrade pip >/dev/null
"$DIR/.venv/bin/pip" install pyatv "srptools==1.0.1"   # srptools récent : appairage Apple TV cassé
if [ "$QT_OK" = "0" ] || ! "$DIR/.venv/bin/python" -c "import PySide6.QtQuick, PySide6.QtSvg" 2>/dev/null; then
  echo "→ PySide6 depuis pip (paquets apt indisponibles)…"
  "$DIR/.venv/bin/pip" install PySide6-Essentials
fi

if [ ! -f "$DIR/config.json" ]; then
  cp "$DIR/config.example.json" "$DIR/config.json"
  echo "→ config.json créé : remplis-le (voir README)."
fi
chmod +x "$DIR/lancer.sh"

echo "→ Démarrage automatique sur l'écran…"
mkdir -p ~/.config/labwc
touch ~/.config/labwc/autostart
sed -i '/maison-facile/d' ~/.config/labwc/autostart
echo "sleep 3 && $DIR/lancer.sh &  # maison-facile" >> ~/.config/labwc/autostart
if [ -f ~/.config/wayfire.ini ]; then     # ancien bureau (Bookworm d'origine)
  grep -q '^\[autostart\]' ~/.config/wayfire.ini || printf '\n[autostart]\n' >> ~/.config/wayfire.ini
  sed -i '/maison-facile/d' ~/.config/wayfire.ini
  sed -i "/^\[autostart\]/a maisonfacile = $DIR/lancer.sh  # maison-facile" ~/.config/wayfire.ini
fi

# Luminosité de l'écran officiel réglable par l'app (baisse au repos)
echo 'SUBSYSTEM=="backlight", RUN+="/bin/chmod 666 /sys/class/backlight/%k/brightness"' \
  | sudo tee /etc/udev/rules.d/99-maison-facile-backlight.rules >/dev/null
sudo udevadm control --reload-rules && sudo udevadm trigger --subsystem-match=backlight || true

# Pas de mise en veille de l'écran par le système ; connexion automatique au bureau
sudo raspi-config nonint do_blanking 1 || true
sudo raspi-config nonint do_boot_behaviour B4 || true

echo
echo "✓ Installé. Configure avec : .venv/bin/python configurer.py"
echo "  (pour tester tout de suite : $DIR/lancer.sh)"
