import QtQuick

// Carte d'une pièce Hue : s'illumine selon l'intensité
Rectangle {
    id: card
    required property string rid
    required property string name
    required property bool lit
    required property int bri
    signal toggled(bool on)
    signal brightness(int bri)       // relâché : on envoie à la Hue
    signal preview(int bri)          // pendant le glissement

    readonly property color fg: on ? "#3a1d00" : "#fbf8ff"
    height: 118
    radius: 22
    color: Qt.rgba(1, 1, 1, 0.07)
    border.width: on ? 0 : 1
    border.color: Qt.rgba(1, 1, 1, 0.09)

    // lueur ambrée
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        opacity: card.lit ? 0.3 + card.bri / 254 * 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#ffd166" }
            GradientStop { position: 1; color: "#ff8f3c" }
        }
    }

    Row {
        x: 18; y: 16
        spacing: 10
        Icon {
            name: "bulb"; tint: card.fg; size: 22
            rotation: card.lit ? -12 : 0
            scale: card.lit ? 1.1 : 1
            Behavior on rotation { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
        }
        Text { text: card.name; color: card.fg; font.pixelSize: 19; font.weight: Font.ExtraBold }
    }

    // interrupteur
    Rectangle {
        id: sw
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 12
        width: 64; height: 36; radius: 18
        color: card.lit ? Qt.rgba(0.23, 0.11, 0, 0.35) : Qt.rgba(1, 1, 1, 0.15)
        Behavior on color { ColorAnimation { duration: 250 } }
        Rectangle {
            width: 28; height: 28; radius: 14
            y: 4
            x: card.lit ? 32 : 4
            Behavior on x { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
            color: "white"
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            onClicked: card.toggled(!card.lit)
        }
    }

    // curseur d'intensité
    Item {
        id: slider
        x: 18
        width: parent.width - 36
        y: 64
        height: 40
        readonly property real frac: (card.bri - 1) / 253
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 12; radius: 6
            color: card.lit ? Qt.rgba(0.23, 0.11, 0, 0.18) : Qt.rgba(1, 1, 1, 0.18)
            Rectangle {
                height: parent.height; radius: 6
                width: Math.max(12, slider.frac * parent.width)
                color: card.lit ? Qt.rgba(0.23, 0.11, 0, 0.8) : "white"
            }
        }
        Rectangle {
            width: 30; height: 30; radius: 15
            color: "white"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.15)
            anchors.verticalCenter: parent.verticalCenter
            x: slider.frac * (slider.width - width)
            scale: sliderMouse.pressed ? 1.15 : 1
            Behavior on scale { NumberAnimation { duration: 150 } }
        }
        MouseArea {
            id: sliderMouse
            anchors.fill: parent
            anchors.topMargin: -10
            anchors.bottomMargin: -10
            preventStealing: true
            function setFrom(mx) {
                var f = Math.max(0, Math.min(1, mx / slider.width))
                card.preview(Math.round(1 + f * 253))
            }
            onPressed: (mouse) => setFrom(mouse.x)
            onPositionChanged: (mouse) => setFrom(mouse.x)
            onReleased: card.brightness(card.bri)
        }
    }
}
