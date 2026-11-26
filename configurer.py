#!/usr/bin/env python3
"""
Assistant de configuration de Maison Facile.

Trouve les appareils sur le réseau (Denon, WiiM, pont Hue, Homey, Apple TV),
appaire la Hue et l'Apple TV, récupère les stores et les préréglages Qobuz,
puis écrit config.json.

    .venv/bin/python configurer.py
"""
import json
import os
import re
import shutil
import subprocess
import sys

BASE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BASE)
CONFIG = os.path.join(BASE, "config.json")
EXAMPLE = os.path.join(BASE, "config.example.json")
VENV_BIN = os.path.join(BASE, ".venv", "bin")

from maison.devices import Hue, Homey, WiiM  # noqa: E402

B, G, Y, R, X = "\033[1m", "\033[32m", "\033[33m", "\033[31m", "\033[0m"


def titre(t):
    print(f"\n{B}── {t} {'─' * max(0, 50 - len(t))}{X}")


def ok(t):
    print(f"{G}✓{X} {t}")


def attention(t):
    print(f"{Y}!{X} {t}")


def demander(question, defaut=""):
    suffixe = f" [{defaut}]" if defaut else ""
    try:
        rep = input(f"{question}{suffixe} : ").strip()
    except EOFError:
        rep = ""
    return rep or defaut


def oui(question, defaut=True):
    rep = demander(question + (" (O/n)" if defaut else " (o/N)")).lower()
    return defaut if not rep else rep.startswith("o") or rep.startswith("y")


def a_remplir(v):
    return not v or "REMPLIR" in str(v) or v == "..."


# ------------------------------------------------------------------ découverte réseau
def decouvrir():
    """Liste les services annoncés sur le réseau local (mDNS) via avahi-browse."""
    if not shutil.which("avahi-browse"):
        attention("avahi-browse absent : sudo apt install avahi-utils (sinon on saisit les adresses à la main)")
        return []
    print("Recherche des appareils sur le réseau (10 s)…")
    try:
        out = subprocess.run(["avahi-browse", "-atrp"], capture_output=True, text=True, timeout=25).stdout
    except subprocess.TimeoutExpired as e:
        out = e.stdout or ""
        if isinstance(out, bytes):
            out = out.decode("utf-8", "replace")
    return analyser_avahi(out)


def analyser_avahi(texte):
    services = []
    for ligne in texte.splitlines():
        p = ligne.split(";")
        if len(p) < 9 or p[0] != "=" or p[2] != "IPv4":
            continue
        nom = re.sub(r"\\(\d{3})", lambda m: chr(int(m.group(1))), p[3])
        services.append({"nom": nom, "type": p[4], "ip": p[7], "port": p[8], "txt": p[9] if len(p) > 9 else ""})
    return services


def trouver(services, types=(), mots=()):
    for s in services:
        if s["type"] in types:
            return s
    for s in services:
        if any(m.lower() in s["nom"].lower() for m in mots):
            return s
    return None


# ------------------------------------------------------------------ étapes
def etape_ip(cfg, cle, libelle, trouve):
    section = cfg.setdefault(cle, {})
    actuel = section.get("host", "")
    exemple = actuel in ("192.168.1.20", "192.168.1.21", "192.168.1.22", "192.168.1.23")
    proposition = trouve["ip"] if trouve else ("" if exemple else actuel)
    if trouve:
        ok(f"{libelle} trouvé : {trouve['nom']} ({trouve['ip']})")
    else:
        attention(f"{libelle} non trouvé automatiquement")
    ip = demander(f"Adresse IP du {libelle} (vide = pas de {libelle})", proposition)
    section["host"] = ip
    return ip


def etape_hue(cfg):
    titre("Lumières Hue")
    hue = cfg["hue"]
    if not hue.get("host"):
        return
    if not a_remplir(hue.get("username")):
        ok("Hue déjà appairée")
        if not oui("Garder cet appairage ?"):
            hue["username"] = ""
        else:
            return
    while True:
        input(f"{B}Appuie sur le gros bouton rond du pont Hue{X}, puis sur Entrée… ")
        try:
            rep = Hue(hue).pair()
            user = rep[0].get("success", {}).get("username") if isinstance(rep, list) and rep else None
        except Exception as e:  # noqa: BLE001
            user, rep = None, str(e)
        if user:
            hue["username"] = user
            ok("Hue appairée")
            try:
                for r in Hue(hue).list_rooms():
                    print(f"   • {r['name']}")
            except Exception:  # noqa: BLE001
                pass
            return
        attention(f"Le pont a refusé ({rep}).")
        if not oui("Réessayer ?"):
            return


def etape_homey(cfg):
    titre("Stores (Homey Pro)")
    homey = cfg["homey"]
    if not homey.get("host"):
        homey["stores"] = []
        return
    if a_remplir(homey.get("token")):
        print("Il faut une clé API du Homey :")
        print("  app Homey → Réglages (⚙) → Clés API → Nouvelle clé → nom « Maison Facile »,")
        print("  coche « Voir les appareils » et « Contrôler les appareils », puis copie la clé.")
        homey["token"] = demander("Colle la clé API ici (vide = plus tard)")
    if a_remplir(homey.get("token")):
        attention("Pas de clé : les stores seront à configurer plus tard (relance cet assistant).")
        homey["stores"] = []
        return
    try:
        devices = Homey(homey).list_devices()
    except Exception as e:  # noqa: BLE001
        attention(f"Impossible de lire les appareils du Homey : {e}")
        return
    stores = [{"name": d["name"], "id": d["id"]} for d in devices.values()
              if "windowcoverings_state" in d.get("capabilities", [])]
    if not stores:
        attention("Aucun store trouvé sur le Homey.")
    for s in stores:
        ok(f"Store : {s['name']}")
    homey["stores"] = sorted(stores, key=lambda s: s["name"])


def etape_presets(cfg):
    titre("Préréglages Qobuz (WiiM)")
    wiim = cfg["wiim"]
    if not wiim.get("host"):
        return
    presets = []
    try:
        info = json.loads(WiiM(wiim)._cmd("getPresetInfo"))
        for p in info.get("preset_list", []):
            nom = (p.get("name") or "").strip()
            if nom:
                presets.append({"name": nom, "sub": p.get("source") or "Qobuz", "preset": int(p.get("number"))})
    except Exception:  # noqa: BLE001
        pass
    if presets:
        for p in presets:
            ok(f"Préréglage {p['preset']} : {p['name']}")
        wiim["presets"] = sorted(presets, key=lambda p: p["preset"])
        return
    attention("Le WiiM n'a pas donné ses préréglages : on les saisit (enregistre-les d'abord dans WiiM Home).")
    if not oui("Saisir les préréglages maintenant ?"):
        return
    wiim["presets"] = []
    for n in range(1, 13):
        nom = demander(f"Nom du préréglage {n} (vide = terminé)")
        if not nom:
            break
        wiim["presets"].append({"name": nom, "sub": "Qobuz", "preset": n})


def etape_appletv(cfg):
    titre("Apple TV")
    atv = cfg.setdefault("appletv", {})
    atvremote = os.path.join(VENV_BIN, "atvremote")
    if not os.path.exists(atvremote):
        attention("pyatv n'est pas installé (relance install.sh). Apple TV ignorée.")
        return
    if not a_remplir(atv.get("identifier")) and not oui("Apple TV déjà configurée. La refaire ?", False):
        return
    print("Recherche des Apple TV…")
    out = subprocess.run([atvremote, "scan"], capture_output=True, text=True, timeout=60).stdout
    appareils = []
    for bloc in out.split("\n\n"):
        nom = re.search(r"Name:\s*(.+)", bloc)
        ident = re.search(r"Identifiers:\s*\n\s*-\s*(\S+)", bloc)
        modele = re.search(r"Model/SW:\s*(.+)", bloc)
        if nom and ident and ((modele and "Apple TV" in modele.group(1)) or "Apple TV" in bloc):
            appareils.append((nom.group(1).strip(), ident.group(1).strip()))
    if not appareils:
        attention("Aucune Apple TV trouvée (allumée et sur le même réseau ?).")
        return
    for i, (n, _) in enumerate(appareils, 1):
        print(f"  {i}. {n}")
    choix = int(demander("Laquelle ?", "1")) - 1
    nom, ident = appareils[max(0, min(choix, len(appareils) - 1))]
    atv["identifier"] = ident
    for proto in ("companion", "airplay"):
        print(f"\n{B}Appairage {proto}{X} : un code va s'afficher sur la TV, tape-le ici.")
        subprocess.run([atvremote, "--id", ident, "--protocol", proto, "pair"])
    out = subprocess.run([atvremote, "--id", ident, "app_list"], capture_output=True, text=True, timeout=60).stdout
    qobuz = [b for n, b in re.findall(r"App:\s*([^,(]+?)\s*\(([^)]+)\)", out) if "qobuz" in n.lower() or "qobuz" in b.lower()]
    if qobuz:
        atv["qobuz_bundle_id"] = qobuz[0]
        ok(f"App Qobuz trouvée ({qobuz[0]})")
    else:
        atv.pop("qobuz_bundle_id", None)
        attention("App Qobuz introuvable sur l'Apple TV : le bouton « Qobuz sur la TV » sera masqué.")
    ok(f"Apple TV configurée : {nom}")


def main():
    src = CONFIG if os.path.exists(CONFIG) else EXAMPLE
    with open(src, encoding="utf-8") as f:
        cfg = json.load(f)
    if src == EXAMPLE:
        # on repart sans les exemples à remplir
        cfg["hue"]["username"] = ""
        cfg["homey"]["token"] = ""
        cfg["homey"]["stores"] = []
        cfg["appletv"] = {}

    print(f"{B}Assistant Maison Facile{X} — Entrée garde la valeur proposée entre crochets.")
    services = decouvrir()

    titre("Adresses des appareils")
    etape_ip(cfg, "denon", "Denon", trouver(services, mots=("denon", "avr-x3800", "x3800h", "marantz")))
    etape_ip(cfg, "wiim", "WiiM", trouver(services, types=("_linkplay._tcp",), mots=("wiim",)))
    etape_ip(cfg, "hue", "pont Hue", trouver(services, types=("_hue._tcp",), mots=("hue bridge", "philips hue")))
    etape_ip(cfg, "homey", "Homey", trouver(services, types=("_homey._tcp",), mots=("homey",)))

    etape_hue(cfg)
    etape_homey(cfg)
    etape_presets(cfg)
    etape_appletv(cfg)

    with open(CONFIG, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    titre("Terminé")
    ok(f"Configuration enregistrée dans {CONFIG}")
    print("Radios et podcasts : modifiables dans config.json (nano config.json).")
    if oui("Relancer l'app sur l'écran maintenant ?"):
        subprocess.run([os.path.join(BASE, "lancer.sh")])


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrompu : rien n'a été enregistré.")
