"""Détection de présence avec la caméra officielle du Pi.

Compare des images en très basse définition (niveaux de gris) : quand assez de
pixels changent, quelqu'un bouge devant l'écran. Rien n'est enregistré ni envoyé.
"""
import threading
import time


class MotionDetector:
    """Logique pure (testable sans caméra) : reçoit des images 2D numpy en niveaux de gris."""

    def __init__(self, sensitivity=0.02, pixel_delta=25, frames_needed=2):
        self.sensitivity = sensitivity      # part de l'image qui doit changer (2 % par défaut)
        self.pixel_delta = pixel_delta      # écart de luminosité pour qu'un pixel « change »
        self.frames_needed = frames_needed  # images consécutives avec mouvement
        self._background = None
        self._hits = 0

    def update(self, gray):
        import numpy as np
        frame = gray.astype(np.float32)
        if self._background is None or self._background.shape != frame.shape:
            self._background = frame
            return False
        changed = np.abs(frame - self._background) > self.pixel_delta
        ratio = float(changed.mean())
        # le fond s'adapte lentement (changements de lumière, soleil…)
        self._background = 0.9 * self._background + 0.1 * frame
        self._hits = self._hits + 1 if ratio >= self.sensitivity else 0
        return self._hits >= self.frames_needed


class PresenceWatcher:
    """Fil de fond : lit la caméra et appelle on_motion() quand quelqu'un bouge."""

    def __init__(self, cfg, on_motion, log=print):
        self.cfg = cfg
        self.on_motion = on_motion
        self.log = log
        self.detector = MotionDetector(
            sensitivity=float(cfg.get("sensitivity", 0.02)),
            pixel_delta=int(cfg.get("pixel_delta", 25)),
        )
        self.interval = 1.0 / float(cfg.get("fps", 4))
        self.cooldown = float(cfg.get("cooldown", 2))
        self._stop = threading.Event()
        self._thread = None

    def start(self):
        self._thread = threading.Thread(target=self._run, daemon=True, name="presence")
        self._thread.start()

    def stop(self):
        self._stop.set()

    def _run(self):
        try:
            from picamera2 import Picamera2
        except ImportError:
            self.log("Présence : picamera2 absent (sudo apt install python3-picamera2) — désactivée")
            return
        try:
            cam = Picamera2()
            cam.configure(cam.create_video_configuration(main={"size": (320, 240), "format": "YUV420"}))
            cam.start()
        except Exception as e:  # noqa: BLE001
            self.log(f"Présence : caméra indisponible ({e}) — désactivée")
            return
        self.log("Présence : caméra active")
        last = 0.0
        try:
            while not self._stop.is_set():
                t0 = time.monotonic()
                try:
                    yuv = cam.capture_array("main")
                    gray = yuv[:240, :320][::4, ::4]      # plan de luminance, 80×60 pixels
                    if self.detector.update(gray) and t0 - last >= self.cooldown:
                        last = t0
                        self.on_motion()
                except Exception as e:  # noqa: BLE001
                    self.log(f"Présence : erreur de lecture ({e})")
                    time.sleep(2)
                self._stop.wait(max(0.0, self.interval - (time.monotonic() - t0)))
        finally:
            try:
                cam.stop()
                cam.close()
            except Exception:  # noqa: BLE001
                pass
