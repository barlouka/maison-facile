#!/usr/bin/env bash
# Lance (ou relance) Maison Facile sur l'écran du Pi. Redémarre l'app si elle plante.
DIR="$(cd "$(dirname "$0")" && pwd)"
LOG="$HOME/.cache/maison-facile.log"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"

if [ "${1:-}" != "--boucle" ]; then
  pkill -f "$DIR/lancer.sh --boucle" 2>/dev/null
  pkill -f "$DIR/app.py" 2>/dev/null
  mkdir -p "$(dirname "$LOG")"
  nohup "$DIR/lancer.sh" --boucle >"$LOG" 2>&1 &
  echo "Maison Facile lancée (journal : $LOG)"
  exit 0
fi

while true; do
  "$DIR/.venv/bin/python" "$DIR/app.py"
  sleep 3
done
