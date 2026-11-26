#!/usr/bin/env bash
# Tourne l'écran du Pi (et le tactile) de façon permanente.
#   ./paysage.sh        → paysage (rotation 90°)
#   ./paysage.sh 270    → paysage dans l'autre sens (si l'image est à l'envers)
#   ./paysage.sh normal → retour au portrait
set -euo pipefail
ROT="${1:-90}"
case "$ROT" in normal|90|180|270) ;; *) echo "Valeur possible : 90, 270, 180 ou normal"; exit 1 ;; esac

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
command -v wlr-randr >/dev/null || sudo apt-get install -y wlr-randr

# Sortie de l'écran tactile (DSI), sinon le premier écran trouvé
OUT=$(wlr-randr | grep -E '^DSI' | head -1 | cut -d' ' -f1 || true)
[ -z "$OUT" ] && OUT=$(wlr-randr | grep -E '^[^ ]' | head -1 | cut -d' ' -f1)
[ -z "$OUT" ] && { echo "Aucun écran trouvé (le bureau est-il démarré ?)"; exit 1; }
echo "→ Écran : $OUT, rotation : $ROT"

# 1. Tout de suite
wlr-randr --output "$OUT" --transform "$ROT"

# 2. À chaque démarrage (kanshi, utilisé par le bureau du Pi)
mkdir -p ~/.config/kanshi
[ -f ~/.config/kanshi/config ] && cp ~/.config/kanshi/config ~/.config/kanshi/config.avant-maison-facile
cat > ~/.config/kanshi/config <<EOF
profile {
    output $OUT enable transform $ROT
}
EOF

# 3. Le tactile suit l'écran
TOUCH=$(sed -n 's/^N: Name="\(.*\)"$/\1/p' /proc/bus/input/devices | grep -iE 'touch|ft5x06|goodix' | head -1 || true)
RC=~/.config/labwc/rc.xml
mkdir -p ~/.config/labwc
if [ ! -f "$RC" ]; then
  printf '<?xml version="1.0"?>\n<labwc_config>\n</labwc_config>\n' > "$RC"
fi
sed -i '/maison-facile-touch/d' "$RC"
if [ -n "$TOUCH" ]; then
  echo "→ Tactile : $TOUCH"
  LINE="  <touch deviceName=\"$TOUCH\" mapToOutput=\"$OUT\" /> <!-- maison-facile-touch -->"
  # insère juste avant la balise fermante finale (labwc_config ou openbox_config)
  CLOSE=$(grep -nE '</(labwc|openbox)_config>' "$RC" | tail -1 | cut -d: -f1)
  if [ -n "$CLOSE" ]; then sed -i "${CLOSE}i\\$LINE" "$RC"; else echo "! $RC illisible : tactile non réglé"; fi
  pkill -HUP -x labwc 2>/dev/null || true   # recharge la configuration du bureau
else
  echo "! Écran tactile non détecté : seule l'image a été tournée."
fi

echo "✓ Fait. Si l'image est à l'envers : ./paysage.sh 270"
