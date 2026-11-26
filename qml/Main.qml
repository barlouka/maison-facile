import QtQuick
import QtQuick.Window

Window {
    id: win
    width: 800
    height: 480
    visible: true
    visibility: startWindowed ? Window.Windowed : Window.FullScreen
    color: "#0c0a18"
    title: backend.config.title || "Maison"

    // ------------------------------------------------------------ état
    readonly property var conf: backend.config
    readonly property var st: backend.status
    readonly property bool landscape: width >= height
    readonly property bool narrow: width < 520
    property string tab: "music"
    property string playingKey: ""
    property int podcastIndex: -1
    property var episodes: []
    property int volLocal: -1
    property double volHoldUntil: 0
    property double lightsHoldUntil: 0
    property bool confirmOff: false

    readonly property var denon: (st && st.denon) ? st.denon : ({})
    readonly property var wiim: (st && st.wiim) ? st.wiim : ({})
    readonly property string nowTitle: wiim.state === "play" && wiim.title ? wiim.title : ""

    // couleurs de chaque univers
    readonly property var gQobuz: ["#7b5cff", "#3b82f6"]
    readonly property var gRadio: ["#ff8a4c", "#ff3d77"]
    readonly property var gPodcast: ["#2dd4a0", "#0ea5c6"]
    readonly property var gTv: ["#8b5cf6", "#ec4899"]
    readonly property var gLight: ["#ffd166", "#ff8f3c"]
    readonly property var gStore: ["#38bdf8", "#6366f1"]
    readonly property var gOff: ["#ff5e62", "#c026d3"]

    // teinte du fond selon l'onglet (transition douce)
    property color c1: tab === "music" ? "#7b5cff" : tab === "tv" ? "#8b5cf6" : tab === "lights" ? "#ff9f43" : "#38bdf8"
    property color c2: tab === "music" ? "#ff4d8d" : tab === "tv" ? "#ec4899" : tab === "lights" ? "#ffd166" : "#6366f1"
    Behavior on c1 { ColorAnimation { duration: 1200; easing.type: Easing.InOutQuad } }
    Behavior on c2 { ColorAnimation { duration: 1200; easing.type: Easing.InOutQuad } }

    // ------------------------------------------------------------ données
    ListModel { id: roomsModel }

    function holdLights() { lightsHoldUntil = Date.now() + 2500 }
    function syncRooms() {
        var list = st && st.lights
        if (!list || list.length === undefined) return
        if (Date.now() < lightsHoldUntil) return
        // mise à jour en place (évite de recréer les cartes)
        if (roomsModel.count !== list.length) {
            roomsModel.clear()
            for (var i = 0; i < list.length; i++)
                roomsModel.append({ rid: String(list[i].id), name: list[i].name, lit: !!list[i].on, bri: list[i].bri || 254 })
            return
        }
        for (var j = 0; j < list.length; j++) {
            roomsModel.setProperty(j, "rid", String(list[j].id))
            roomsModel.setProperty(j, "name", list[j].name)
            roomsModel.setProperty(j, "lit", !!list[j].on)
            roomsModel.setProperty(j, "bri", list[j].bri || 254)
        }
    }

    onStChanged: {
        syncRooms()
        if (Date.now() > volHoldUntil) volLocal = (typeof denon.volume === "number") ? denon.volume : -1
        if (wiim.state && wiim.state !== "play" && wiim.state !== "load" && wiim.state !== "loading") playingKey = ""
    }

    Connections {
        target: backend
        function onToast(msg, err) { toast.show(msg, err) }
        function onEpisodesReady(i, list) { if (i === win.podcastIndex) win.episodes = list }
        function onStopped() { win.playingKey = "" }
    }

    function stepVolume(step) {
        if (volLocal >= 0) volLocal = Math.max(0, Math.min(denon.max_volume || 70, volLocal + step))
        volHoldUntil = Date.now() + 1500
        bump.restart()
        backend.volumeStep(step)
    }

    // ------------------------------------------------------------ fond aurore
    Item {
        id: aurora
        anchors.fill: parent
        clip: true
        readonly property real m: Math.max(win.width, win.height)

        Blob {
            id: b1
            tint: win.c1
            width: aurora.m * 0.95; height: width
            opacity: 0.42
            x: -width * 0.3; y: -height * 0.35
            SequentialAnimation on x { loops: Animation.Infinite
                NumberAnimation { to: aurora.width * 0.2; duration: 22000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -b1.width * 0.3; duration: 22000; easing.type: Easing.InOutSine } }
            SequentialAnimation on y { loops: Animation.Infinite
                NumberAnimation { to: aurora.height * 0.05; duration: 17000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -b1.height * 0.35; duration: 17000; easing.type: Easing.InOutSine } }
        }
        Blob {
            id: b2
            tint: win.c2
            width: aurora.m * 1.0; height: width
            opacity: 0.36
            x: aurora.width - width * 0.6; y: aurora.height - height * 0.55
            SequentialAnimation on x { loops: Animation.Infinite
                NumberAnimation { to: aurora.width * 0.1; duration: 26000; easing.type: Easing.InOutSine }
                NumberAnimation { to: aurora.width - b2.width * 0.6; duration: 26000; easing.type: Easing.InOutSine } }
            SequentialAnimation on scale { loops: Animation.Infinite
                NumberAnimation { to: 1.2; duration: 19000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 19000; easing.type: Easing.InOutSine } }
        }
        Blob {
            id: b3
            tint: "#22d3ee"
            width: aurora.m * 0.6; height: width
            opacity: 0.16
            x: aurora.width * 0.35; y: aurora.height * 0.3
            SequentialAnimation on x { loops: Animation.Infinite
                NumberAnimation { to: -b3.width * 0.2; duration: 30000; easing.type: Easing.InOutSine }
                NumberAnimation { to: aurora.width * 0.35; duration: 30000; easing.type: Easing.InOutSine } }
        }
    }

    // ------------------------------------------------------------ en-tête + onglets
    Item {
        id: side
        x: 0; y: 0
        width: win.landscape ? 178 : win.width
        height: win.landscape ? win.height - footer.height : sideCol.height + 18

        Column {
            id: sideCol
            x: 14; y: 14
            width: parent.width - 28
            spacing: 10

            Item {
                width: parent.width
                height: win.landscape ? titleText.height + (nowPill.visible ? nowPill.height + 6 : 0) : Math.max(titleText.height, 34)
                Text {
                    id: titleText
                    text: win.conf.title || "Maison"
                    font.pixelSize: win.landscape ? 26 : 30
                    font.weight: Font.Black
                    color: "white"
                }
                // pastille « en lecture »
                Rectangle {
                    id: nowPill
                    visible: opacity > 0
                    opacity: win.nowTitle !== "" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                    height: 28
                    radius: 14
                    width: Math.min(nowRow.implicitWidth + 22, win.landscape ? parent.width : parent.width * 0.6)
                    x: win.landscape ? 0 : parent.width - width
                    y: win.landscape ? titleText.height + 6 : (parent.height - height) / 2
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    clip: true
                    Row {
                        id: nowRow
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7
                        Eq { barHeight: 13; tint: win.c2; running: nowPill.visible; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: win.nowTitle
                            color: "white"; font.pixelSize: 12; font.weight: Font.DemiBold
                            width: Math.min(implicitWidth, nowPill.width - 40)
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Grid {
                id: navGrid
                width: parent.width
                columns: win.landscape ? 1 : 4
                spacing: 8
                readonly property real cellW: win.landscape ? width : (width - 3 * spacing) / 4
                Repeater {
                    model: [
                        { key: "music",  icon: "music",  label: "Musique",  g: win.gQobuz, dark: false },
                        { key: "tv",     icon: "tv",     label: "TV",       g: win.gTv,    dark: false },
                        { key: "lights", icon: "bulb",   label: "Lumières", g: win.gLight, dark: true },
                        { key: "stores", icon: "blinds", label: "Stores",   g: win.gStore, dark: false }
                    ]
                    NavButton {
                        required property var modelData
                        width: navGrid.cellW
                        compact: !win.landscape && win.narrow
                        icon: modelData.icon; label: modelData.label
                        a: modelData.g[0]; b: modelData.g[1]; dark: modelData.dark
                        active: win.tab === modelData.key
                        onClicked: {
                            win.tab = modelData.key
                            if (modelData.key === "lights") backend.refresh()
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ pages
    Item {
        id: pages
        x: win.landscape ? side.width : 0
        y: win.landscape ? 0 : side.height
        width: win.width - x
        height: win.height - y - footer.height
        clip: true
        readonly property real pad: win.landscape ? 8 : 14
        readonly property real innerW: width - pad - 16
        readonly property int cols: Math.max(2, Math.floor((innerW + 10) / 150))
        readonly property real tileW: (innerW - (cols - 1) * 10) / cols

        // ---------- Musique
        Page {
            id: musicPage
            name: "music"
            shown: win.tab === "music"
            pad: pages.pad
            Column {
                id: musicCol
                width: pages.innerW
                spacing: 0

                SectionTitle { text: "Qobuz"; dot: "#7b8cff"; visible: (win.conf.presets || []).length > 0 }
                Grid {
                    columns: pages.cols; spacing: 10
                    Repeater {
                        model: win.conf.presets || []
                        Tile {
                            required property var modelData
                            required property int index
                            width: pages.tileW
                            a: win.gQobuz[0]; b: win.gQobuz[1]; icon: "disc"
                            label: modelData.name; sub: modelData.sub || "Qobuz"
                            idx: index; active: musicPage.shown
                            playing: win.playingKey === "p" + modelData.preset
                            onClicked: { win.playingKey = "p" + modelData.preset; backend.preset(modelData.preset, modelData.name) }
                        }
                    }
                }

                SectionTitle { text: "Radio"; dot: "#ff6b6b"; visible: (win.conf.radios || []).length > 0 }
                Grid {
                    columns: pages.cols; spacing: 10
                    Repeater {
                        model: win.conf.radios || []
                        Tile {
                            required property var modelData
                            required property int index
                            width: pages.tileW
                            a: win.gRadio[0]; b: win.gRadio[1]; icon: "radio"
                            label: modelData.name; sub: modelData.sub || "Radio"
                            idx: index + 3; active: musicPage.shown
                            playing: win.playingKey === "r" + index
                            onClicked: { win.playingKey = "r" + index; backend.radio(index) }
                        }
                    }
                }

                SectionTitle { text: "Podcasts"; dot: "#2dd4a0"; visible: (win.conf.podcasts || []).length > 0 }
                Grid {
                    columns: pages.cols; spacing: 10
                    Repeater {
                        model: win.conf.podcasts || []
                        Tile {
                            required property var modelData
                            required property int index
                            width: pages.tileW
                            a: win.gPodcast[0]; b: win.gPodcast[1]; icon: "mic"
                            label: modelData.name; sub: "Derniers épisodes"
                            idx: index + 6; active: musicPage.shown
                            playing: win.playingKey === "pod" + modelData.index
                            onClicked: {
                                win.podcastIndex = modelData.index
                                win.episodes = []
                                backend.loadEpisodes(modelData.index)
                            }
                        }
                    }
                }

                // épisodes du podcast choisi
                Column {
                    width: parent.width
                    spacing: 8
                    topPadding: win.podcastIndex >= 0 ? 12 : 0
                    visible: win.podcastIndex >= 0
                    Text {
                        visible: win.episodes.length === 0
                        text: "Chargement…"
                        color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 14
                    }
                    Repeater {
                        model: win.episodes
                        Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 64
                            radius: 18
                            color: Qt.rgba(1, 1, 1, 0.07)
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.09)
                            Column {
                                x: 16
                                width: parent.width - 90
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text { width: parent.width; text: modelData.title; color: "white"; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { width: parent.width; text: modelData.date; color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 12 }
                            }
                            GlassButton {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46; height: 46; radius: 23; border.width: 0
                                icon: "play"; iconSize: 18
                                a: win.gPodcast[0]; b: win.gPodcast[1]
                                pressA: win.gPodcast[1]; pressB: win.gPodcast[0]
                                onClicked: {
                                    win.playingKey = "pod" + win.podcastIndex
                                    backend.listen(modelData.url, modelData.title)
                                }
                            }
                        }
                    }
                }

                SectionTitle { text: "Lecture"; dot: "white" }
                Grid {
                    columns: pages.cols; spacing: 10
                    Tile {
                        width: pages.tileW; glass: true; icon: "pause"; label: "Pause / reprise"
                        idx: 9; active: musicPage.shown
                        onClicked: backend.pause()
                    }
                    Tile {
                        width: pages.tileW; glass: true; icon: "stop"; label: "Arrêter"
                        idx: 10; active: musicPage.shown
                        onClicked: backend.stop()
                    }
                }
            }
        }

        // ---------- TV
        Page {
            id: tvPage
            name: "tv"
            shown: win.tab === "tv"
            pad: pages.pad
            Column {
                width: pages.innerW
                spacing: 10
                Item { width: 1; height: 4 }
                Tile {
                    width: parent.width; big: true
                    a: win.gTv[0]; b: win.gTv[1]; icon: "apple"
                    label: "Apple TV"; sub: "Allume tout et met la bonne entrée"
                    idx: 0; active: tvPage.shown
                    onClicked: backend.watch(false)
                }
                Tile {
                    visible: !!win.conf.qobuz
                    width: pages.tileW
                    a: win.gQobuz[0]; b: win.gQobuz[1]; icon: "disc"
                    label: "Qobuz sur la TV"; sub: "Ouvre l'app Qobuz"
                    idx: 1; active: tvPage.shown
                    onClicked: backend.watch(true)
                }
                SectionTitle { text: "Télécommande"; dot: "#ec4899" }
                Grid {
                    id: remote
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: 3
                    spacing: 8
                    readonly property real bw: Math.min(96, (pages.innerW - 16) / 3)
                    readonly property real bh: win.landscape ? 58 : 76
                    GlassButton { width: remote.bw; height: remote.bh; label: "Retour"; onClicked: backend.key("menu") }
                    GlassButton { width: remote.bw; height: remote.bh; icon: "up"; onClicked: backend.key("up") }
                    GlassButton { width: remote.bw; height: remote.bh; label: "Accueil"; onClicked: backend.key("home") }
                    GlassButton { width: remote.bw; height: remote.bh; icon: "left"; onClicked: backend.key("left") }
                    Item {
                        width: remote.bw; height: remote.bh
                        GlassButton {
                            anchors.centerIn: parent
                            width: Math.min(remote.bw, remote.bh) * 1.05; height: width; radius: width / 2
                            border.width: 0
                            label: "OK"
                            a: win.gTv[0]; b: win.gTv[1]; pressA: win.gTv[1]; pressB: win.gTv[0]
                            onClicked: backend.key("select")
                        }
                    }
                    GlassButton { width: remote.bw; height: remote.bh; icon: "right"; onClicked: backend.key("right") }
                    GlassButton { width: remote.bw; height: remote.bh; icon: "prev"; onClicked: backend.key("previous") }
                    GlassButton { width: remote.bw; height: remote.bh; icon: "down"; onClicked: backend.key("down") }
                    GlassButton { width: remote.bw; height: remote.bh; icon: "next"; onClicked: backend.key("next") }
                    Item { width: remote.bw; height: remote.bh }
                    GlassButton { width: remote.bw; height: remote.bh; icon: "playpause"; onClicked: backend.key("playpause") }
                    Item { width: remote.bw; height: remote.bh }
                }
            }
        }

        // ---------- Lumières
        Page {
            id: lightsPage
            name: "lights"
            shown: win.tab === "lights"
            pad: pages.pad
            Column {
                width: pages.innerW
                spacing: 10
                Item { width: 1; height: 4 }
                Tile {
                    width: pages.tileW; glass: true; icon: "moon"
                    label: "Tout éteindre"; sub: "Toutes les lumières"
                    idx: 0; active: lightsPage.shown
                    onClicked: {
                        for (var i = 0; i < roomsModel.count; i++) roomsModel.setProperty(i, "lit", false)
                        win.holdLights()
                        backend.lightsOff()
                    }
                }
                Text {
                    visible: roomsModel.count === 0
                    text: (win.st && win.st.lights && win.st.lights.error) ? "Lumières injoignables." : "Chargement…"
                    color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 15
                }
                Repeater {
                    model: roomsModel
                    RoomCard {
                        required property int index
                        width: pages.innerW
                        onToggled: (v) => {
                            roomsModel.setProperty(index, "lit", v)
                            win.holdLights()
                            backend.lightOn(rid, v)
                        }
                        onPreview: (v) => {
                            roomsModel.setProperty(index, "bri", v)
                            roomsModel.setProperty(index, "lit", true)
                            win.holdLights()
                        }
                        onBrightness: (v) => { win.holdLights(); backend.lightBri(rid, v) }
                    }
                }
            }
        }

        // ---------- Stores
        Page {
            id: storesPage
            name: "stores"
            shown: win.tab === "stores"
            pad: pages.pad
            Column {
                width: pages.innerW
                spacing: 10
                Item { width: 1; height: 4 }
                Text {
                    visible: (win.conf.stores || []).length === 0
                    text: "Aucun store configuré."
                    color: Qt.rgba(1, 1, 1, 0.6); font.pixelSize: 15
                }
                StoreRow {
                    visible: (win.conf.stores || []).length > 0
                    width: pages.innerW
                    sid: "all"; name: "Tous les stores"; all: true
                    onAction: (what) => {
                        for (var i = 0; i < storeRep.count; i++) storeRep.itemAt(i).move(what)
                        backend.store("all", what)
                    }
                }
                Repeater {
                    id: storeRep
                    model: win.conf.stores || []
                    StoreRow {
                        required property var modelData
                        width: pages.innerW
                        sid: modelData.id; name: modelData.name
                        onAction: (what) => backend.store(sid, what)
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ barre du bas
    Rectangle {
        id: footer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 70
        color: Qt.rgba(0.03, 0.03, 0.06, 0.78)
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.09) }

        Row {
            id: fRow
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            readonly property real volW: footer.width - 28 - 3 * 52 - offBtn.width - 4 * spacing

            GlassButton { width: 52; height: 52; radius: 16; icon: "minus"; onClicked: win.stepVolume(-1) }
            Item {
                width: fRow.volW
                height: 52
                Text {
                    id: volText
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 4
                    text: win.denon.error ? "!" : (win.denon.power ? (win.volLocal >= 0 ? win.volLocal : "–") : "Éteint")
                    color: "white"
                    font.pixelSize: 22; font.weight: Font.Black
                    SequentialAnimation on scale {
                        id: bump
                        running: false
                        NumberAnimation { to: 1.25; duration: 110; easing.type: Easing.OutQuad }
                        NumberAnimation { to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 38
                    width: Math.min(parent.width - 10, 260); height: 6; radius: 3
                    color: Qt.rgba(1, 1, 1, 0.12)
                    Rectangle {
                        height: parent.height; radius: 3
                        width: parent.width * ((win.denon.power && win.volLocal >= 0) ? Math.min(1, win.volLocal / (win.denon.max_volume || 70)) : 0)
                        Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutBack } }
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: win.c1 }
                            GradientStop { position: 1; color: win.c2 }
                        }
                    }
                }
            }
            GlassButton { width: 52; height: 52; radius: 16; icon: "plus"; onClicked: win.stepVolume(1) }
            GlassButton {
                width: 52; height: 52; radius: 16; icon: "mute"
                a: win.denon.mute ? win.gOff[0] : Qt.rgba(1, 1, 1, 0.07)
                b: win.denon.mute ? win.gOff[1] : Qt.rgba(1, 1, 1, 0.07)
                onClicked: backend.mute(!win.denon.mute)
            }
            GlassButton {
                id: offBtn
                width: win.narrow ? 84 : 120; height: 52; radius: 16; border.width: 0
                a: win.gOff[0]; b: win.gOff[1]; pressA: win.gOff[1]; pressB: win.gOff[0]
                onClicked: win.confirmOff = true
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { name: "power"; tint: "white"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: win.narrow ? "Tout" : "Tout éteindre"
                        color: "white"; font.pixelSize: 14; font.weight: Font.ExtraBold
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ message
    Rectangle {
        id: toast
        property bool err: false
        property alias text: toastText.text
        function show(msg, e) { text = msg; err = e; toastAnim.restart() }
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.height - footer.height - height - 16 + offset
        property real offset: 30
        opacity: 0
        width: Math.min(toastText.implicitWidth + 40, win.width - 40)
        height: 44
        radius: 22
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: toast.err ? "#ff5e62" : win.c1 }
            GradientStop { position: 1; color: toast.err ? "#b91c1c" : win.c2 }
        }
        Text {
            id: toastText
            anchors.centerIn: parent
            width: parent.width - 32
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: "white"; font.pixelSize: 15; font.weight: Font.Bold
        }
        SequentialAnimation {
            id: toastAnim
            ParallelAnimation {
                NumberAnimation { target: toast; property: "opacity"; to: 1; duration: 250 }
                NumberAnimation { target: toast; property: "offset"; from: 30; to: 0; duration: 420; easing.type: Easing.OutBack }
            }
            PauseAnimation { duration: toast.err ? 3600 : 1600 }
            ParallelAnimation {
                NumberAnimation { target: toast; property: "opacity"; to: 0; duration: 300 }
                NumberAnimation { target: toast; property: "offset"; to: 20; duration: 300 }
            }
        }
    }

    // ------------------------------------------------------------ confirmation « Tout éteindre »
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: opacity > 0
        opacity: win.confirmOff ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        MouseArea { anchors.fill: parent; onClicked: win.confirmOff = false }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(380, win.width - 40)
            height: 190
            radius: 26
            color: "#1b1830"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            scale: win.confirmOff ? 1 : 0.85
            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
            MouseArea { anchors.fill: parent }   // le toucher sur la carte ne ferme pas

            Column {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 8
                Text { text: "Tout éteindre ?"; color: "white"; font.pixelSize: 22; font.weight: Font.Black }
                Text {
                    width: parent.width
                    text: "Musique, TV, ampli et lumières."
                    color: Qt.rgba(1, 1, 1, 0.65); font.pixelSize: 15; wrapMode: Text.WordWrap
                }
                Item { width: 1; height: 14 }
                Row {
                    spacing: 10
                    GlassButton {
                        width: (parent.parent.width - 10) / 2; height: 54; label: "Annuler"
                        onClicked: win.confirmOff = false
                    }
                    GlassButton {
                        width: (parent.parent.width - 10) / 2; height: 54; border.width: 0
                        a: win.gOff[0]; b: win.gOff[1]; pressA: win.gOff[1]; pressB: win.gOff[0]
                        label: "Éteindre"
                        onClicked: { win.confirmOff = false; win.playingKey = ""; backend.allOff() }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------ horloge au repos
    Rectangle {
        id: clock
        anchors.fill: parent
        color: "black"
        visible: opacity > 0
        opacity: backend.idle ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 800 } }
        property date now: new Date()

        Timer {
            running: backend.idle
            interval: 5000; repeat: true; triggeredOnStart: true
            onTriggered: clock.now = new Date()
        }

        Column {
            anchors.centerIn: parent
            spacing: win.height * 0.03
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real sz: Math.min(win.width * 0.27, win.height * 0.42)
                Text { id: hh; text: Qt.formatTime(clock.now, "HH"); font.pixelSize: parent.sz; font.weight: Font.Light; color: clockColor.c }
                Text {
                    text: ":"; font.pixelSize: parent.sz; font.weight: Font.Light; color: clockColor.c
                    SequentialAnimation on opacity {
                        running: backend.idle; loops: Animation.Infinite
                        PauseAnimation { duration: 1000 }
                        NumberAnimation { to: 0.25; duration: 0 }
                        PauseAnimation { duration: 1000 }
                        NumberAnimation { to: 1; duration: 0 }
                    }
                }
                Text { text: Qt.formatTime(clock.now, "mm"); font.pixelSize: parent.sz; font.weight: Font.Light; color: clockColor.c }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    var s = clock.now.toLocaleDateString(Qt.locale("fr_CH"), "dddd d MMMM")
                    return s.charAt(0).toUpperCase() + s.slice(1)
                }
                color: "#77737f"
                font.pixelSize: Math.min(win.width * 0.05, win.height * 0.06)
            }
        }

        // couleur des chiffres qui change lentement
        Item {
            id: clockColor
            property color c: "#ffb347"
            SequentialAnimation on c {
                running: backend.idle
                loops: Animation.Infinite
                ColorAnimation { to: "#ff5f8f"; duration: 6000 }
                ColorAnimation { to: "#a78bfa"; duration: 6000 }
                ColorAnimation { to: "#ffb347"; duration: 6000 }
            }
        }
    }
}
