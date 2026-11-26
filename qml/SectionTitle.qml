import QtQuick

// Titre de section avec pastille lumineuse
Row {
    id: row
    property string text: ""
    property color dot: "#ff4d8d"
    spacing: 8
    topPadding: 14
    bottomPadding: 8
    Item {
        width: 8
        height: label.height
        Rectangle {
            anchors.centerIn: parent
            width: 8; height: 8; radius: 4
            color: row.dot
        }
    }
    Text {
        id: label
        text: row.text.toUpperCase()
        color: Qt.rgba(0.94, 0.92, 1, 0.6)
        font.pixelSize: 12
        font.weight: Font.ExtraBold
        font.letterSpacing: 1.4
    }
}
