import QtQuick
import QtQuick.Shapes

// Halo de couleur flou pour le fond « aurore »
Item {
    id: blob
    property color tint: "#7b5cff"
    width: 600
    height: 600

    Shape {
        anchors.fill: parent
        ShapePath {
            strokeColor: "transparent"
            strokeWidth: 0
            fillGradient: RadialGradient {
                centerX: blob.width / 2
                centerY: blob.height / 2
                centerRadius: blob.width / 2
                focalX: blob.width / 2
                focalY: blob.height / 2
                GradientStop { position: 0.0; color: blob.tint }
                GradientStop { position: 0.35; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0.45) }
                GradientStop { position: 1.0; color: Qt.rgba(blob.tint.r, blob.tint.g, blob.tint.b, 0) }
            }
            startX: 0; startY: 0
            PathLine { x: blob.width; y: 0 }
            PathLine { x: blob.width; y: blob.height }
            PathLine { x: 0; y: blob.height }
            PathLine { x: 0; y: 0 }
        }
    }
}
