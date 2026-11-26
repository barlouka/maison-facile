"""Icônes SVG dessinées à la volée dans n'importe quelle couleur (image://icon/<nom>/<rrggbb>)."""
from PySide6.QtCore import QByteArray, QSize, Qt
from PySide6.QtGui import QImage, QPainter
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtSvg import QSvgRenderer

ICONS = {
    "music": '<path d="M9 18V5l11-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="17" cy="16" r="3"/>',
    "disc": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2.5"/><path d="M12 3a9 9 0 0 1 9 9"/>',
    "radio": '<rect x="3" y="8" width="18" height="12" rx="3"/><path d="M7 8 17 3"/><circle cx="15.5" cy="14" r="2.5"/><path d="M6.5 12.5h3M6.5 15.5h3"/>',
    "mic": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
    "tv": '<rect x="3" y="5" width="18" height="12" rx="2.5"/><path d="M8 21h8M12 17v4"/>',
    "bulb": '<path d="M9 18h6M10 21h4"/><path d="M12 3a6 6 0 0 0-3.5 10.9c.6.5 1 1.2 1 2.1h5c0-.9.4-1.6 1-2.1A6 6 0 0 0 12 3Z"/>',
    "blinds": '<path d="M4 3h16M5 3v13M19 3v13M5 7h14M5 11h14M5 15h14"/><path d="M12 16v3"/><circle cx="12" cy="20.5" r="1.2"/>',
    "power": '<path d="M12 3v8"/><path d="M6.4 6.6a8 8 0 1 0 11.2 0"/>',
    "minus": '<path d="M5 12h14"/>',
    "plus": '<path d="M12 5v14M5 12h14"/>',
    "mute": '<path d="M11 5 6 9H3v6h3l5 4V5Z"/><path d="m22 9-6 6M16 9l6 6"/>',
    "play": '<path d="M7 4v16l13-8Z" fill="currentColor"/>',
    "stop": '<rect x="6" y="6" width="12" height="12" rx="2" fill="currentColor"/>',
    "playpause": '<path d="M4 5v14l8-7Z" fill="currentColor"/><path d="M15 5v14M20 5v14"/>',
    "up": '<path d="m6 15 6-6 6 6"/>',
    "down": '<path d="m6 9 6 6 6-6"/>',
    "left": '<path d="m15 6-6 6 6 6"/>',
    "right": '<path d="m9 6 6 6-6 6"/>',
    "prev": '<path d="M19 5 9 12l10 7Z" fill="currentColor"/><path d="M5 5v14"/>',
    "next": '<path d="m5 5 10 7-10 7Z" fill="currentColor"/><path d="M19 5v14"/>',
    "moon": '<path d="M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5Z"/>',
    "sun": '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
    "pause": '<path d="M8 5v14M16 5v14"/>',
    "apple": '<rect x="3" y="5" width="18" height="12" rx="2.5"/><path d="m10 9 5 2-5 2Z" fill="currentColor"/><path d="M8 21h8"/>',
}

SVG = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#{c}" '
       'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" color="#{c}">{p}</svg>')


class IconProvider(QQuickImageProvider):
    def __init__(self):
        try:
            kind = QQuickImageProvider.ImageType.Image
        except AttributeError:
            from PySide6.QtQml import QQmlImageProviderBase
            kind = QQmlImageProviderBase.ImageType.Image
        super().__init__(kind)
        self._cache = {}

    def requestImage(self, ident, size, requested):
        name, _, color = ident.partition("/")
        color = (color or "ffffff")[:6]
        w = requested.width() if requested.width() > 0 else 48
        h = requested.height() if requested.height() > 0 else w
        key = (name, color, w, h)
        if key not in self._cache:
            svg = SVG.format(c=color, p=ICONS.get(name, "").replace("currentColor", "#" + color))
            img = QImage(QSize(w, h), QImage.Format.Format_ARGB32_Premultiplied)
            img.fill(Qt.GlobalColor.transparent)
            p = QPainter(img)
            p.setRenderHint(QPainter.RenderHint.Antialiasing)
            QSvgRenderer(QByteArray(svg.encode())).render(p)
            p.end()
            self._cache[key] = img
        return self._cache[key]
