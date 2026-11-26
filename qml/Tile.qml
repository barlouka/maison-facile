import QtQuick

// Tuile colorée en dégradé, avec icône, texte, rebond au toucher et apparition animée
Item {
    id: t
    property color a: "#7b5cff"
    property color b: "#3b82f6"
    property string icon: "music"
    property string label: ""
    property string sub: ""
    property bool dark: false          // texte foncé (tuiles claires)
    property bool glass: false         // tuile « verre » discrète
    property bool playing: false
    property bool big: false
    property int idx: 0
    property bool active: true         // la page est affichée
    signal clicked()

    readonly property color fg: dark ? "#3a1d00" : "#ffffff"
    height: big ? 112 : 96

    // apparition en cascade quand la page s'affiche
    opacity: 0
    property real lift: 16
    transform: Translate { y: t.lift }
    function intro() { introAnim.restart() }
    onActiveChanged: if (active) intro()
    Component.onCompleted: if (active) intro()
    SequentialAnimation {
        id: introAnim
        PropertyAction { target: t; property: "opacity"; value: 0 }
        PropertyAction { target: t; property: "lift"; value: 16 }
        PauseAnimation { duration: t.idx * 45 }
        ParallelAnimation {
            NumberAnimation { target: t; property: "opacity"; to: 1; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: t; property: "lift"; to: 0; duration: 520; easing.type: Easing.OutBack }
        }
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 20
        scale: mouse.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
        border.width: t.playing ? 3 : (t.glass ? 1 : 0)
        border.color: t.playing ? "#ffffff" : Qt.rgba(1, 1, 1, 0.1)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: t.glass ? Qt.rgba(1, 1, 1, 0.10) : t.a }
            GradientStop { position: 1.0; color: t.glass ? Qt.rgba(1, 1, 1, 0.06) : t.b }
        }

        // reflet brillant en haut
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: mouse.pressed ? 0.35 : 0.18
            Behavior on opacity { NumberAnimation { duration: 150 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ffffff" }
                GradientStop { position: 0.55; color: "transparent" }
            }
        }

        Rectangle {
            id: iconBox
            x: 14; y: 14
            width: t.big ? 48 : 36
            height: width
            radius: width * 0.32
            color: t.dark ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.22)
            Icon {
                anchors.centerIn: parent
                name: t.icon
                tint: t.fg
                size: t.big ? 26 : 20
            }
        }

        Eq {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 20
            barHeight: 18
            visible: t.playing
            running: t.playing
            tint: t.fg
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 14
            spacing: 2
            Text {
                width: parent.width
                text: t.label
                color: t.fg
                font.pixelSize: t.big ? 24 : 16
                font.weight: Font.ExtraBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: t.sub !== ""
                text: t.sub
                color: t.fg
                opacity: 0.78
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        onClicked: t.clicked()
    }
}
