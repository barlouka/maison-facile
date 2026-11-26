import QtQuick

// Onglet : verre au repos, dégradé coloré quand il est actif
Item {
    id: nb
    property string icon
    property string label
    property color a
    property color b
    property bool active: false
    property bool dark: false
    property bool compact: false     // icône au-dessus du texte (téléphone / portrait étroit)
    signal clicked()

    readonly property color fg: active ? (dark ? "#3a1d00" : "#ffffff") : Qt.rgba(0.94, 0.92, 1, 0.6)
    height: compact ? 62 : 52
    scale: ma.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(1, 1, 1, 0.07)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.09)
    }
    Rectangle {
        anchors.fill: parent
        radius: 16
        opacity: nb.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: nb.a }
            GradientStop { position: 1; color: nb.b }
        }
    }

    Row {
        visible: !nb.compact
        anchors.verticalCenter: parent.verticalCenter
        x: 14
        spacing: 10
        Icon { name: nb.icon; tint: nb.fg; size: 20; anchors.verticalCenter: parent.verticalCenter }
        Text {
            text: nb.label; color: nb.fg
            font.pixelSize: 16; font.weight: Font.Bold
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Column {
        visible: nb.compact
        anchors.centerIn: parent
        spacing: 4
        Icon { name: nb.icon; tint: nb.fg; size: 22; anchors.horizontalCenter: parent.horizontalCenter }
        Text {
            text: nb.label; color: nb.fg
            font.pixelSize: 12; font.weight: Font.Bold
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea { id: ma; anchors.fill: parent; onClicked: nb.clicked() }
}
