import QtQuick

// Petit égaliseur animé (indique ce qui joue)
Row {
    id: eq
    property color tint: "white"
    property real barHeight: 14
    property bool running: true
    spacing: 2
    height: barHeight

    Repeater {
        model: [700, 520, 860, 610]
        Rectangle {
            required property int modelData
            width: 3
            radius: 1.5
            color: eq.tint
            y: eq.barHeight - height
            height: eq.barHeight * 0.3
            SequentialAnimation on height {
                running: eq.running && eq.visible
                loops: Animation.Infinite
                NumberAnimation { to: eq.barHeight; duration: modelData / 2; easing.type: Easing.InOutSine }
                NumberAnimation { to: eq.barHeight * 0.25; duration: modelData / 2; easing.type: Easing.InOutSine }
            }
        }
    }
}
