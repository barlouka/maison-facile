#!/usr/bin/env bash
# Affiche Maison Facile en plein écran sur l'écran tactile du Pi, à chaque démarrage.
# À lancer une fois, après install.sh :  ./kiosk.sh
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=$(python3 -c "import json;print(json.load(open('$DIR/config.json')).get('port',8000))" 2>/dev/null || echo 8000)
BROWSER=$(command -v chromium || command -v chromium-browser || true)
[ -z "$BROWSER" ] && { echo "Chromium introuvable : sudo apt install chromium"; exit 1; }

CMD="$BROWSER --kiosk --noerrdialogs --disable-infobars --no-first-run --incognito \
--disable-pinch --overscroll-history-navigation=0 --check-for-update-interval=31536000 \
--password-store=basic http://localhost:$PORT"

# Raspberry Pi OS Bookworm (bureau labwc)
mkdir -p ~/.config/labwc
touch ~/.config/labwc/autostart
sed -i '/maison-facile/d' ~/.config/labwc/autostart
echo "sleep 4 && $CMD &  # maison-facile" >> ~/.config/labwc/autostart

# Ancien bureau (wayfire) : on l'ajoute aussi, sans effet s'il n'est pas utilisé
if [ -f ~/.config/wayfire.ini ]; then
  grep -q '^\[autostart\]' ~/.config/wayfire.ini || printf '\n[autostart]\n' >> ~/.config/wayfire.ini
  sed -i '/maison-facile/d' ~/.config/wayfire.ini
  sed -i "/^\[autostart\]/a maisonfacile = sleep 4 \&\& $CMD  # maison-facile" ~/.config/wayfire.ini
fi

# Autorise l'app à baisser la luminosité de l'écran officiel au repos
echo 'SUBSYSTEM=="backlight", RUN+="/bin/chmod 666 /sys/class/backlight/%k/brightness"' | sudo tee /etc/udev/rules.d/99-maison-facile-backlight.rules >/dev/null

# Le Pi ne met plus l'écran en veille : l'app affiche sa propre horloge au repos
sudo raspi-config nonint do_blanking 1 || true
# Connexion automatique au bureau
sudo raspi-config nonint do_boot_behaviour B4 || true

echo "✓ Kiosque activé. Redémarre le Pi : sudo reboot"
echo "  Pour quitter le kiosque : branche un clavier et fais Alt+F4."
