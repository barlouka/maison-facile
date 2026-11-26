import QtQuick

// Bouton « verre » avec icône (télécommande, barre du bas, stores)
Rectangle {
    id: rb
    property string icon: ""
    property string label: ""
    property int iconSize: 24
    property color a: Qt.rgba(1, 1, 1, 0.07)
    property color b: Qt.rgba(1, 1, 1, 0.07)
    property color fg: "#fbf8ff"
    property color pressA: Qt.rgba(1, 1, 1, 0.16)
    property color pressB: Qt.rgba(1, 1, 1, 0.16)
    signal clicked()

    radius: 18
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.09)
    scale: ma.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: ma.pressed ? rb.pressA : rb.a }
        GradientStop { position: 1; color: ma.pressed ? rb.pressB : rb.b }
    }

    Icon { visible: rb.icon !== ""; anchors.centerIn: parent; name: rb.icon; tint: rb.fg; size: rb.iconSize }
    Text {
        visible: rb.icon === "" && rb.label !== ""
        anchors.centerIn: parent
        text: rb.label; color: rb.fg
        font.pixelSize: 15; font.weight: Font.Bold
    }
    MouseArea { id: ma; anchors.fill: parent; onClicked: rb.clicked() }
}
