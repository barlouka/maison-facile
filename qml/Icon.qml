import QtQuick

// Icône SVG dessinée par Python dans la couleur voulue
Image {
    property string name: "music"
    property color tint: "white"
    property int size: 22
    width: size
    height: size
    sourceSize: Qt.size(size * 2, size * 2)
    smooth: true
    source: "image://icon/" + name + "/" + tint.toString().replace("#", "").slice(-6)
}
