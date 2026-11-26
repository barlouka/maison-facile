#!/usr/bin/env bash
# Installe Maison Facile comme service qui démarre avec le Raspberry Pi.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="$(whoami)"

echo "→ Environnement Python (avec pyatv pour l'Apple TV)…"
python3 -m venv "$DIR/.venv"
"$DIR/.venv/bin/pip" install --upgrade pip >/dev/null
"$DIR/.venv/bin/pip" install pyatv

if [ ! -f "$DIR/config.json" ]; then
  cp "$DIR/config.example.json" "$DIR/config.json"
  echo "→ config.json créé : remplis-le avant de lancer le service."
fi

echo "→ Service systemd…"
sudo tee /etc/systemd/system/maison-facile.service >/dev/null <<EOF
[Unit]
Description=Maison Facile
After=network-online.target
Wants=network-online.target

[Service]
User=$USER_NAME
WorkingDirectory=$DIR
ExecStart=$DIR/.venv/bin/python $DIR/server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable maison-facile
sudo systemctl restart maison-facile
echo "✓ Terminé. Ouvre http://$(hostname).local:$(python3 -c "import json;print(json.load(open('$DIR/config.json')).get('port',8000))")"
