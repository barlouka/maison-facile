import QtQuick

// Page défilante qui apparaît en fondu quand son onglet est choisi
Flickable {
    id: pg
    property string name
    property bool shown: false
    property real pad: 8

    anchors.fill: parent
    leftMargin: pad
    topMargin: 6
    bottomMargin: 24
    contentWidth: width - pad
    contentHeight: contentItem.childrenRect.height
    flickableDirection: Flickable.VerticalFlick
    boundsBehavior: Flickable.DragOverBounds
    clip: true

    enabled: shown
    visible: opacity > 0
    opacity: shown ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    property real slide: shown ? 0 : 14
    Behavior on slide { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
    transform: Translate { y: pg.slide }

    onShownChanged: if (shown) contentY = -topMargin
}
