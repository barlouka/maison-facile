#!/usr/bin/env python3
"""
Maison Facile — serveur domotique simple pour Raspberry Pi.

Pilote : ampli Denon (HTTP), WiiM (HTTP API), lumières Hue (pont local),
stores Somfy via le Homey Pro (API locale), Apple TV (pyatv, optionnel).

Lancement :  python3 server.py
Aides     :  python3 server.py --pair-hue | --list-homey | --list-hue
"""
import asyncio
import json
import os
import ssl
import sys
import threading
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BASE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.environ.get("MAISON_CONFIG", os.path.join(BASE, "config.json"))
STATIC = os.path.join(BASE, "static")


def load_config():
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return json.load(f)


CFG = load_config() if os.path.exists(CONFIG_PATH) else {}

# Le WiiM utilise un certificat auto-signé : on n'accepte cela QUE pour lui.
_WIIM_SSL = ssl.create_default_context()
_WIIM_SSL.check_hostname = False
_WIIM_SSL.verify_mode = ssl.CERT_NONE


def http(method, url, body=None, headers=None, timeout=4, context=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    if data is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=timeout, context=context) as r:
        return r.read().decode("utf-8", "replace")


# ----------------------------------------------------------------- Denon
class Denon:
    # Codes d'entrée Denon
    INPUTS = {"mediaplayer": "MPLAY", "appletv": "SAT/CBL", "tv": "TV", "bluetooth": "BT"}

    def __init__(self, cfg):
        self.host = cfg.get("host")
        self.port = cfg.get("http_port", 8080)
        self.max_volume = cfg.get("max_volume", 70)

    def _cmd(self, code):
        url = f"http://{self.host}:{self.port}/goform/formiPhoneAppDirect.xml?{urllib.parse.quote(code, safe='/')}"
        http("GET", url)

    def power(self, on):
        self._cmd("PWON" if on else "PWSTANDBY")

    def source(self, name):
        self._cmd("SI" + self.INPUTS.get(name, name))

    def volume_step(self, up):
        # Un appui = 1 point de volume (le Denon avance par demi-points)
        for _ in range(2):
            self._cmd("MVUP" if up else "MVDOWN")

    def volume_set(self, v):
        v = max(0, min(int(v), self.max_volume))
        self._cmd(f"MV{v:02d}")

    def mute(self, on):
        self._cmd("MUON" if on else "MUOFF")

    def status(self):
        url = f"http://{self.host}:{self.port}/goform/formMainZone_MainZoneXmlStatusLite.xml"
        root = ET.fromstring(http("GET", url))

        def val(tag):
            el = root.find(f"{tag}/value")
            return el.text.strip() if el is not None and el.text else None

        vol = val("MasterVolume")
        try:
            vol = round(float(vol) + 80)  # dB relatif -> échelle 0..98
        except (TypeError, ValueError):
            vol = None
        return {
            "power": (val("Power") or "").upper() == "ON",
            "input": val("InputFuncSelect"),
            "volume": vol,
            "mute": (val("Mute") or "").lower() == "on",
            "max_volume": self.max_volume,
        }


# ----------------------------------------------------------------- WiiM
class WiiM:
    def __init__(self, cfg):
        self.host = cfg.get("host")

    def _cmd(self, command):
        url = f"https://{self.host}/httpapi.asp?command={urllib.parse.quote(command, safe=':/')}"
        return http("GET", url, context=_WIIM_SSL)

    def play_url(self, url):
        self._cmd("setPlayerCmd:play:" + url)

    def preset(self, n):
        # Joue le préréglage n (1..12) enregistré dans l'app WiiM Home (ex. playlist Qobuz)
        self._cmd(f"MCUKeyShortClick:{int(n)}")

    def pause(self):
        self._cmd("setPlayerCmd:onepause")

    def stop(self):
        self._cmd("setPlayerCmd:stop")

    def status(self):
        try:
            s = json.loads(self._cmd("getPlayerStatus"))
        except ValueError:
            return {}
        return {"state": s.get("status"), "title": _hexdecode(s.get("Title", ""))}


def _hexdecode(s):
    try:
        return bytes.fromhex(s).decode("utf-8")
    except (ValueError, TypeError):
        return s


# ----------------------------------------------------------------- Hue
class Hue:
    def __init__(self, cfg):
        self.host = cfg.get("host")
        self.user = cfg.get("username")
        self.rooms = cfg.get("rooms")  # liste optionnelle d'ID de pièces à afficher

    def _url(self, path):
        return f"http://{self.host}/api/{self.user}/{path}"

    def list_rooms(self):
        groups = json.loads(http("GET", self._url("groups")))
        out = []
        for gid, g in groups.items():
            if g.get("type") not in ("Room", "Zone"):
                continue
            if self.rooms and gid not in self.rooms:
                continue
            out.append({
                "id": gid,
                "name": g.get("name"),
                "on": g.get("state", {}).get("any_on", False),
                "bri": g.get("action", {}).get("bri", 254),
            })
        return sorted(out, key=lambda r: r["name"])

    def set_room(self, gid, on=None, bri=None):
        body = {}
        if on is not None:
            body["on"] = bool(on)
        if bri is not None:
            body["bri"] = max(1, min(int(bri), 254))
            body["on"] = True
        http("PUT", self._url(f"groups/{gid}/action"), body)

    def all_off(self):
        http("PUT", self._url("groups/0/action"), {"on": False})

    def pair(self):
        r = json.loads(http("POST", f"http://{self.host}/api", {"devicetype": "maison_facile#pi"}))
        return r


# ----------------------------------------------------------------- Homey
class Homey:
    def __init__(self, cfg):
        self.host = cfg.get("host")
        self.token = cfg.get("token")
        self.stores = cfg.get("stores", [])

    def _h(self):
        return {"Authorization": f"Bearer {self.token}"}

    def set_capability(self, device_id, cap, value):
        url = f"http://{self.host}/api/manager/devices/device/{device_id}/capability/{cap}"
        http("PUT", url, {"value": value}, self._h())

    def store(self, device_id, action):
        # action : up | idle | down  (capability standard des stores sur Homey)
        self.set_capability(device_id, "windowcoverings_state", action)

    def list_devices(self):
        url = f"http://{self.host}/api/manager/devices/device/"
        return json.loads(http("GET", url, headers=self._h(), timeout=10))


# ----------------------------------------------------------------- Apple TV (pyatv)
class AppleTV:
    """Contrôle via pyatv dans une boucle asyncio dédiée. Optionnel."""

    def __init__(self, cfg):
        self.cfg = cfg
        self.available = False
        self.atv = None
        self.error = None
        try:
            import pyatv  # noqa: F401
            self.available = bool(cfg.get("identifier"))
            if not self.available:
                self.error = "Apple TV non configurée (identifier manquant)"
        except ImportError:
            self.error = "pyatv n'est pas installé"
        if self.available:
            self.loop = asyncio.new_event_loop()
            threading.Thread(target=self.loop.run_forever, daemon=True).start()

    def _run(self, coro, timeout=15):
        return asyncio.run_coroutine_threadsafe(coro, self.loop).result(timeout)

    async def _connect(self):
        if self.atv is not None:
            return self.atv
        import pyatv
        from pyatv.storage.file_storage import FileStorage
        storage = FileStorage.default_storage(self.loop)
        await storage.load()
        found = await pyatv.scan(self.loop, identifier=self.cfg["identifier"], storage=storage, timeout=5)
        if not found:
            raise RuntimeError("Apple TV introuvable sur le réseau")
        self.atv = await pyatv.connect(found[0], self.loop, storage=storage)
        return self.atv

    def _reset(self):
        try:
            if self.atv:
                self.atv.close()
        except Exception:
            pass
        self.atv = None

    def call(self, fn):
        if not self.available:
            raise RuntimeError(self.error)

        async def go():
            atv = await self._connect()
            return await fn(atv)

        try:
            return self._run(go())
        except Exception:
            self._reset()  # on retente une fois avec une connexion neuve
            return self._run(go())

    def power(self, on):
        return self.call(lambda a: a.power.turn_on() if on else a.power.turn_off())

    def key(self, k):
        keys = {
            "up": "up", "down": "down", "left": "left", "right": "right",
            "select": "select", "menu": "menu", "home": "home",
            "playpause": "play_pause", "next": "next", "previous": "previous",
        }
        if k not in keys:
            raise ValueError("touche inconnue")
        return self.call(lambda a: getattr(a.remote_control, keys[k])())

    def launch(self, bundle_id):
        return self.call(lambda a: a.apps.launch_app(bundle_id))


# ----------------------------------------------------------------- Podcasts
_podcast_cache = {}


def podcast_episodes(rss, n=8):
    now = time.time()
    if rss in _podcast_cache and now - _podcast_cache[rss][0] < 1800:
        return _podcast_cache[rss][1]
    root = ET.fromstring(http("GET", rss, timeout=10))
    eps = []
    for item in root.iter("item"):
        enc = item.find("enclosure")
        if enc is None or not enc.get("url"):
            continue
        eps.append({
            "title": (item.findtext("title") or "").strip(),
            "date": (item.findtext("pubDate") or "")[:16],
            "url": enc.get("url"),
        })
        if len(eps) >= n:
            break
    _podcast_cache[rss] = (now, eps)
    return eps


# ----------------------------------------------------------------- Écran tactile du Pi
def set_backlight(bright, dim_percent=8):
    """Règle le rétroéclairage de l'écran officiel (s'il existe)."""
    import glob
    for d in glob.glob("/sys/class/backlight/*"):
        try:
            mx = int(open(os.path.join(d, "max_brightness")).read())
            val = mx if bright else max(1, mx * dim_percent // 100)
            with open(os.path.join(d, "brightness"), "w") as f:
                f.write(str(val))
        except OSError:
            pass


# ----------------------------------------------------------------- Application
class House:
    def __init__(self, cfg):
        self.cfg = cfg
        self.denon = Denon(cfg.get("denon", {}))
        self.wiim = WiiM(cfg.get("wiim", {}))
        self.hue = Hue(cfg.get("hue", {}))
        self.homey = Homey(cfg.get("homey", {}))
        self.atv = AppleTV(cfg.get("appletv", {}))

    # Scénarios « un bouton »
    def listen(self, url):
        self.denon.power(True)
        self.denon.source("mediaplayer")
        self.wiim.play_url(url)

    def listen_preset(self, n):
        self.denon.power(True)
        self.denon.source("mediaplayer")
        self.wiim.preset(n)

    def watch_appletv(self, app=None):
        errors = []
        try:
            self.denon.power(True)
            self.denon.source("appletv")
        except Exception as e:
            errors.append(f"Denon : {e}")
        try:
            self.atv.power(True)
            if app:
                self.atv.launch(app)
        except Exception as e:
            errors.append(f"Apple TV : {e}")
        if errors:
            raise RuntimeError(" / ".join(errors))

    def everything_off(self):
        errors = []
        for label, fn in [
            ("WiiM", self.wiim.stop),
            ("Apple TV", lambda: self.atv.power(False) if self.atv.available else None),
            ("Denon", lambda: self.denon.power(False)),
            ("Lumières", self.hue.all_off),
        ]:
            try:
                fn()
            except Exception as e:
                errors.append(f"{label} : {e}")
        if errors:
            raise RuntimeError(" / ".join(errors))

    def config_public(self):
        c = self.cfg
        return {
            "title": c.get("title", "Maison"),
            "presets": c.get("wiim", {}).get("presets", []),
            "radios": c.get("radios", []),
            "podcasts": [{"name": p["name"], "index": i} for i, p in enumerate(c.get("podcasts", []))],
            "stores": [{"name": s["name"], "id": s["id"]} for s in c.get("homey", {}).get("stores", [])],
            "qobuz": bool(c.get("appletv", {}).get("qobuz_bundle_id")),
            "appletv": self.atv.available,
            "appletv_error": self.atv.error,
            "idle_seconds": c.get("idle_seconds", 60),
        }


HOUSE = None


def route(method, path, q, body, client=None):
    h = HOUSE
    b = body or {}
    if method == "GET":
        if path == "/api/config":
            return h.config_public()
        if path == "/api/status":
            out = {}
            for k, fn in [("denon", h.denon.status), ("wiim", h.wiim.status), ("lights", h.hue.list_rooms)]:
                try:
                    out[k] = fn()
                except Exception as e:
                    out[k] = {"error": str(e)}
            return out
        if path == "/api/podcast":
            p = h.cfg["podcasts"][int(q.get("i", ["0"])[0])]
            return podcast_episodes(p["rss"])
    if method == "POST":
        if path == "/api/listen":
            h.listen(b["url"]); return {"ok": True}
        if path == "/api/radio":
            h.listen(h.cfg["radios"][int(b["index"])]["url"]); return {"ok": True}
        if path == "/api/preset":
            h.listen_preset(b["preset"]); return {"ok": True}
        if path == "/api/wiim/pause":
            h.wiim.pause(); return {"ok": True}
        if path == "/api/wiim/stop":
            h.wiim.stop(); return {"ok": True}
        if path == "/api/denon/power":
            h.denon.power(b["on"]); return {"ok": True}
        if path == "/api/denon/volume":
            if "step" in b:
                h.denon.volume_step(b["step"] > 0)
            else:
                h.denon.volume_set(b["value"])
            return {"ok": True}
        if path == "/api/denon/mute":
            h.denon.mute(b["on"]); return {"ok": True}
        if path == "/api/appletv/watch":
            app = h.cfg.get("appletv", {}).get("qobuz_bundle_id") if b.get("qobuz") else None
            h.watch_appletv(app); return {"ok": True}
        if path == "/api/appletv/key":
            h.atv.key(b["key"]); return {"ok": True}
        if path == "/api/lights/room":
            h.hue.set_room(b["id"], b.get("on"), b.get("bri")); return {"ok": True}
        if path == "/api/lights/off":
            h.hue.all_off(); return {"ok": True}
        if path == "/api/store":
            ids = [s["id"] for s in h.cfg["homey"]["stores"]] if b["id"] == "all" else [b["id"]]
            for i in ids:
                h.homey.store(i, b["action"])
            return {"ok": True}
        if path == "/api/off":
            h.everything_off(); return {"ok": True}
        if path == "/api/screen":
            # Seul l'écran branché sur le Pi (localhost) règle sa propre luminosité
            if client in ("127.0.0.1", "::1"):
                set_backlight(bool(b.get("on")), h.cfg.get("screen_dim_percent", 8))
            return {"ok": True}
    raise KeyError(path)


MIME = {".html": "text/html; charset=utf-8", ".js": "application/javascript", ".css": "text/css",
        ".json": "application/json", ".png": "image/png", ".svg": "image/svg+xml",
        ".webmanifest": "application/manifest+json"}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        if os.environ.get("MAISON_DEBUG"):
            super().log_message(fmt, *args)

    def _send(self, code, data, ctype="application/json"):
        raw = data if isinstance(data, bytes) else json.dumps(data, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def _handle(self, method):
        u = urllib.parse.urlparse(self.path)
        if u.path.startswith("/api/"):
            body = None
            if method == "POST":
                n = int(self.headers.get("Content-Length") or 0)
                body = json.loads(self.rfile.read(n) or b"{}")
            try:
                self._send(200, route(method, u.path, urllib.parse.parse_qs(u.query), body, self.client_address[0]))
            except KeyError as e:
                self._send(404, {"error": f"inconnu : {e}"})
            except Exception as e:
                self._send(502, {"error": str(e)})
            return
        # fichiers statiques
        rel = "index.html" if u.path in ("/", "") else u.path.lstrip("/")
        full = os.path.normpath(os.path.join(STATIC, rel))
        if not full.startswith(STATIC) or not os.path.isfile(full):
            return self._send(404, b"Not found", "text/plain")
        with open(full, "rb") as f:
            self._send(200, f.read(), MIME.get(os.path.splitext(full)[1], "application/octet-stream"))

    def do_GET(self):
        self._handle("GET")

    def do_POST(self):
        self._handle("POST")


def main():
    global HOUSE
    if not CFG:
        sys.exit(f"Fichier de configuration introuvable : {CONFIG_PATH}\n"
                 "Copie config.example.json en config.json et remplis-le.")
    HOUSE = House(CFG)
    args = sys.argv[1:]
    if "--pair-hue" in args:
        input("Appuie sur le bouton du pont Hue, puis sur Entrée… ")
        print(json.dumps(HOUSE.hue.pair(), indent=2))
        print("Copie la valeur « username » dans config.json > hue > username.")
        return
    if "--list-hue" in args:
        for r in HOUSE.hue.list_rooms():
            print(f'{r["id"]:>4}  {r["name"]}')
        return
    if "--list-homey" in args:
        for d in HOUSE.homey.list_devices().values():
            caps = d.get("capabilities", [])
            mark = "  <- store" if "windowcoverings_state" in caps else ""
            print(f'{d["id"]}  {d["name"]}{mark}')
        return
    port = int(CFG.get("port", 8000))
    srv = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"Maison Facile prête : http://<ip-du-pi>:{port}")
    srv.serve_forever()


if __name__ == "__main__":
    main()
