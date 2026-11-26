import QtQuick

// Une ligne de store avec une petite fenêtre animée
Rectangle {
    id: row
    property string sid
    property string name
    property bool all: false
    property real pos: 0.12          // part de la fenêtre couverte par le store (0..1)
    signal action(string what)

    height: 72
    radius: 22
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.09)
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: row.all ? Qt.rgba(0.22, 0.74, 0.97, 0.2) : Qt.rgba(1, 1, 1, 0.07) }
        GradientStop { position: 1; color: row.all ? Qt.rgba(0.39, 0.4, 0.95, 0.2) : Qt.rgba(1, 1, 1, 0.07) }
    }

    function move(what) {
        if (what === "up") curtain.target = 0.12
        else if (what === "down") curtain.target = 0.92
        else curtain.freeze()
    }

    // fenêtre
    Rectangle {
        id: pane
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 46; height: 46; radius: 12
        clip: true
        border.width: 2
        border.color: Qt.rgba(1, 1, 1, 0.35)
        gradient: Gradient {
            GradientStop { position: 0; color: "#bfe6ff" }
            GradientStop { position: 0.6; color: "#7dd3fc" }
            GradientStop { position: 1; color: "#a7f3d0" }
        }
        Item {
            id: curtain
            property real target: row.pos
            property real frac: target
            function freeze() { anim.stop(); target = frac }
            onTargetChanged: { anim.from = frac; anim.to = target; anim.restart() }
            NumberAnimation {
                id: anim
                target: curtain; property: "frac"
                duration: 1600; easing.type: Easing.InOutQuad
            }
            width: parent.width
            height: parent.height * frac
            clip: true
            Column {
                Repeater {
                    model: 12
                    Rectangle {
                        width: 46; height: 7
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#6366f1" }
                            GradientStop { position: 0.7; color: "#6366f1" }
                            GradientStop { position: 0.71; color: "#4338ca" }
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.left: pane.right
        anchors.leftMargin: 12
        anchors.right: buttons.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: row.name
        color: "#fbf8ff"
        font.pixelSize: 17
        font.weight: Font.ExtraBold
        elide: Text.ElideRight
    }

    Row {
        id: buttons
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Repeater {
            model: [["up", "up"], ["pause", "idle"], ["down", "down"]]
            GlassButton {
                required property var modelData
                width: 54; height: 50; radius: 15
                icon: modelData[0]; iconSize: 22
                pressA: "#38bdf8"; pressB: "#6366f1"
                onClicked: { row.move(modelData[1]); row.action(modelData[1]) }
            }
        }
    }
}
