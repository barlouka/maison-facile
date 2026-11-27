"""Pont entre l'interface QML et les appareils.

Chaque action part dans un fil séparé pour que l'interface reste fluide ;
les résultats reviennent dans le fil principal par des signaux Qt.
"""
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QEvent, QObject, Property, Qt, QTimer, Signal, Slot

from .devices import House, podcast_episodes, set_backlight


class Backend(QObject):
    statusChanged = Signal()
    idleChanged = Signal()
    toast = Signal(str, bool)                  # message, erreur ?
    episodesReady = Signal(int, "QVariant")    # index du podcast, liste d'épisodes
    stopped = Signal()                          # la musique a été arrêtée

    # signaux internes : ramènent les résultats dans le fil principal
    _statusIn = Signal(object)
    _toastIn = Signal(str, bool)
    _episodesIn = Signal(int, object)
    _stoppedIn = Signal()
    _motionIn = Signal()

    def __init__(self, cfg):
        super().__init__()
        self.cfg = cfg
        self.house = House(cfg)
        self._config = self.house.config_public()
        self._status = {}
        self._idle = False
        self._pool = ThreadPoolExecutor(max_workers=4)

        q = Qt.ConnectionType.QueuedConnection
        self._statusIn.connect(self._setStatus, q)
        self._toastIn.connect(self.toast, q)
        self._episodesIn.connect(self._emitEpisodes, q)
        self._stoppedIn.connect(self.stopped, q)
        self._motionIn.connect(self._onMotion, q)

        self._poll = QTimer(self)
        self._poll.setInterval(8000)
        self._poll.timeout.connect(self.refresh)
        self._poll.start()
        self._idleTimer = QTimer(self)
        self._idleTimer.setSingleShot(True)
        self._idleTimer.timeout.connect(self._goIdle)
        self._idleSeconds = int(cfg.get("idle_seconds", 60))
        self._dim = int(cfg.get("screen_dim_percent", 8))
        self.activity()
        self.refresh()

        # Caméra : quelqu'un s'approche → l'écran se rallume (et reste allumé tant que ça bouge)
        self._presence = None
        cam = cfg.get("camera", {})
        if cam.get("enabled"):
            from .presence import PresenceWatcher
            self._presence = PresenceWatcher(cam, self._motionIn.emit)
            self._presence.start()

    # ---------------------------------------------------------------- propriétés
    def _getConfig(self):
        return self._config

    def _getStatus(self):
        return self._status

    def _getIdle(self):
        return self._idle

    config = Property("QVariant", _getConfig, constant=True)
    status = Property("QVariant", _getStatus, notify=statusChanged)
    idle = Property(bool, _getIdle, notify=idleChanged)

    @Slot(int, object)
    def _emitEpisodes(self, i, eps):
        self.episodesReady.emit(i, eps)

    @Slot(object)
    def _setStatus(self, st):
        self._status = st
        self.statusChanged.emit()

    # ---------------------------------------------------------------- outils
    def _run(self, fn, ok=None, then_refresh=True):
        def job():
            try:
                fn()
                if ok:
                    self._toastIn.emit(ok, False)
            except Exception as e:  # noqa: BLE001
                self._toastIn.emit(f"Oups : {e}", True)
            if then_refresh:
                self._statusIn.emit(self.house.status())
        self._pool.submit(job)

    @Slot()
    def refresh(self):
        if self._idle:
            return
        self._pool.submit(lambda: self._statusIn.emit(self.house.status()))

    # ---------------------------------------------------------------- musique
    @Slot(int, str)
    def preset(self, n, name):
        self._run(lambda: self.house.listen_preset(n), "♪ " + name)

    @Slot(int)
    def radio(self, i):
        r = self.cfg["radios"][i]
        self._run(lambda: self.house.listen(r["url"]), "♪ " + r["name"])

    @Slot(str, str)
    def listen(self, url, title):
        self._run(lambda: self.house.listen(url), "♪ " + title)

    @Slot(int)
    def loadEpisodes(self, i):
        rss = self.cfg["podcasts"][i]["rss"]

        def job():
            try:
                self._episodesIn.emit(i, podcast_episodes(rss))
            except Exception:  # noqa: BLE001
                self._episodesIn.emit(i, [])
                self._toastIn.emit("Podcast indisponible", True)
        self._pool.submit(job)

    @Slot()
    def pause(self):
        self._run(self.house.wiim.pause)

    @Slot()
    def stop(self):
        def fn():
            self.house.wiim.stop()
            self._stoppedIn.emit()
        self._run(fn)

    # ---------------------------------------------------------------- ampli
    @Slot(int)
    def volumeStep(self, step):
        self._run(lambda: self.house.denon.volume_step(step > 0))

    @Slot(bool)
    def mute(self, on):
        self._run(lambda: self.house.denon.mute(on))

    # ---------------------------------------------------------------- Apple TV
    @Slot(bool)
    def watch(self, qobuz):
        app = self.cfg.get("appletv", {}).get("qobuz_bundle_id") if qobuz else None
        self._run(lambda: self.house.watch_appletv(app), "Apple TV prête")

    @Slot(str)
    def key(self, k):
        self._run(lambda: self.house.atv.key(k), then_refresh=False)

    # ---------------------------------------------------------------- lumières
    @Slot(str, bool)
    def lightOn(self, gid, on):
        self._run(lambda: self.house.hue.set_room(gid, on=on))

    @Slot(str, int)
    def lightBri(self, gid, bri):
        self._run(lambda: self.house.hue.set_room(gid, bri=bri))

    @Slot()
    def lightsOff(self):
        self._run(self.house.hue.all_off, "Lumières éteintes")

    # ---------------------------------------------------------------- stores
    @Slot(str, str)
    def store(self, sid, action):
        ids = [s["id"] for s in self.cfg["homey"]["stores"]] if sid == "all" else [sid]

        def fn():
            for i in ids:
                self.house.homey.store(i, action)
        self._run(fn, then_refresh=False)

    # ---------------------------------------------------------------- tout
    @Slot()
    def allOff(self):
        def fn():
            self.house.everything_off()
            self._stoppedIn.emit()
        self._run(fn, "Bonne nuit")

    # ---------------------------------------------------------------- veille
    def activity(self):
        """Appelé à chaque toucher. Retourne True si ce toucher a servi à réveiller l'écran."""
        woke = False
        if self._idle:
            self._idle = False
            woke = True
            self.idleChanged.emit()
            self._pool.submit(lambda: set_backlight(True, self._dim))
            self.refresh()
        if self._idleSeconds > 0:
            self._idleTimer.start(self._idleSeconds * 1000)
        return woke

    @Slot()
    def _onMotion(self):
        self.activity()

    def _goIdle(self):
        self._idle = True
        self.idleChanged.emit()
        self._pool.submit(lambda: set_backlight(False, self._dim))

    def shutdown(self):
        if self._presence:
            self._presence.stop()
        self._pool.shutdown(wait=False, cancel_futures=True)
        set_backlight(True, self._dim)


class ActivityFilter(QObject):
    """Repère chaque toucher : réveille l'écran (et avale ce toucher-là)."""

    _TYPES = {QEvent.Type.MouseButtonPress, QEvent.Type.TouchBegin, QEvent.Type.KeyPress}

    def __init__(self, backend):
        super().__init__()
        self.backend = backend
        self._swallow = False

    def eventFilter(self, obj, ev):
        t = ev.type()
        if t in self._TYPES:
            if self.backend.activity():
                self._swallow = True
                return True
        if self._swallow and t in (QEvent.Type.MouseButtonRelease, QEvent.Type.TouchEnd,
                                   QEvent.Type.MouseMove, QEvent.Type.TouchUpdate):
            if t in (QEvent.Type.MouseButtonRelease, QEvent.Type.TouchEnd):
                self._swallow = False
            return True
        return False
