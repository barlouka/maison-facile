#!/usr/bin/env python3
"""
Maison Facile — app native (Qt/QML) pour le Raspberry Pi et son écran tactile.

Lancement :  python3 app.py            (plein écran)
             python3 app.py --fenetre  (dans une fenêtre, pour tester)
Aides     :  python3 app.py --pair-hue | --list-hue | --list-homey
"""
import json
import os
import signal
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.environ.get("MAISON_CONFIG", os.path.join(BASE, "config.json"))


def load_config():
    if not os.path.exists(CONFIG_PATH):
        sys.exit(f"Fichier de configuration introuvable : {CONFIG_PATH}\n"
                 "Copie config.example.json en config.json et remplis-le.")
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return json.load(f)


def helpers(cfg, args):
    """Commandes d'aide à la configuration (sans interface graphique)."""
    from maison.devices import House
    house = House(cfg)
    if "--pair-hue" in args:
        input("Appuie sur le bouton du pont Hue, puis sur Entrée… ")
        print(json.dumps(house.hue.pair(), indent=2))
        print("Copie la valeur « username » dans config.json > hue > username.")
    elif "--list-hue" in args:
        for r in house.hue.list_rooms():
            print(f'{r["id"]:>4}  {r["name"]}')
    elif "--list-homey" in args:
        for d in house.homey.list_devices().values():
            mark = "  <- store" if "windowcoverings_state" in d.get("capabilities", []) else ""
            print(f'{d["id"]}  {d["name"]}{mark}')
    else:
        return False
    return True


def main():
    cfg = load_config()
    args = sys.argv[1:]
    if helpers(cfg, args):
        return

    from PySide6.QtCore import Qt, QUrl
    from PySide6.QtGui import QCursor, QFont, QFontDatabase, QGuiApplication
    from PySide6.QtQml import QQmlApplicationEngine

    from maison.backend import ActivityFilter, Backend
    from maison.icons import IconProvider

    app = QGuiApplication(sys.argv)
    app.setApplicationName("Maison Facile")
    for fam in ("Inter", "Inter Variable", "Noto Sans", "DejaVu Sans"):
        if fam in QFontDatabase.families():
            app.setFont(QFont(fam, 12))
            break

    windowed = "--fenetre" in args or cfg.get("fullscreen") is False
    if cfg.get("hide_cursor", True) and not windowed:
        app.setOverrideCursor(QCursor(Qt.CursorShape.BlankCursor))

    backend = Backend(cfg)
    filt = ActivityFilter(backend)
    app.installEventFilter(filt)

    engine = QQmlApplicationEngine()
    engine.addImageProvider("icon", IconProvider())
    engine.rootContext().setContextProperty("backend", backend)
    engine.rootContext().setContextProperty("startWindowed", windowed)
    engine.load(QUrl.fromLocalFile(os.path.join(BASE, "qml", "Main.qml")))
    if not engine.rootObjects():
        sys.exit("Impossible de charger l'interface (voir les erreurs QML ci-dessus).")

    signal.signal(signal.SIGINT, lambda *_: app.quit())
    signal.signal(signal.SIGTERM, lambda *_: app.quit())
    # Laisse Python traiter Ctrl+C / l'arrêt du service même pendant la boucle Qt
    from PySide6.QtCore import QTimer
    tick = QTimer()
    tick.timeout.connect(lambda: None)
    tick.start(500)
    app.aboutToQuit.connect(backend.shutdown)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
