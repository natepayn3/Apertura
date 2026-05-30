import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: audioRoot
    implicitWidth: 32
    implicitHeight: 32

    readonly property real currentVol: globalVolumeSlider.value ?? 0.0
    property bool isMuted: false
    property bool menuOpen: false

    Binding {
        target: rootScope
        property: "audioSliderActive"
        value: globalVolumeSlider.pressed
    }

    Timer {
        interval: 400
        running: true
        repeat: true
        onTriggered: {
            if (!globalVolumeSlider.pressed) {
                syncVolumeQuery.running = false;
                syncVolumeQuery.running = true;
            }
            if (globalVolumeModal.visible) {
                syncDevicesQuery.running = false;
                syncDevicesQuery.running = true;
            }
        }
    }

    Process {
        id: syncVolumeQuery
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let cleaned = text.trim();
                    if (cleaned.startsWith("Volume:")) {
                        audioRoot.isMuted = cleaned.includes("[MUTED]");
                        let parts = cleaned.split(" ");
                        if (parts.length >= 2) {
                            let volVal = parseFloat(parts[1]);
                            if (!isNaN(volVal) && !globalVolumeSlider.pressed) {
                                if (Math.abs(globalVolumeSlider.value - volVal) > 0.001) {
                                    globalVolumeSlider.value = volVal;
                                    checkUserActivity();
                                }
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: syncDevicesQuery
        command: ["wpctl", "status"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let lines = text.split("\n");
                    let parsingSinks = false;
                    let currentSinks = [];

                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i];

                        if (line.includes("Sinks:")) {
                            parsingSinks = true;
                            continue;
                        }

                        if (parsingSinks && (line.includes("Sources:") || line.includes("Filters:") || line.includes("Streams:"))) {
                            parsingSinks = false;
                        }

                        if (parsingSinks) {
                            let match = line.match(/(\*\s*)?\s*(\d+)\.\s+(.*)/);
                            if (match) {
                                let isActive = (match[1] !== undefined && match[1].includes("*"));
                                let devId = match[2].trim();
                                let rawName = match[3].trim();
                                let cleanName = rawName.split("[")[0].trim();

                                currentSinks.push({
                                    "devId": devId,
                                    "name": cleanName,
                                    "active": isActive
                                });
                            }
                        }
                    }

                    for (let m = 0; m < currentSinks.length; m++) {
                        let found = false;
                        for (let n = 0; n < deviceListModel.count; n++) {
                            if (deviceListModel.get(n).devId === currentSinks[m].devId) {
                                found = true;
                                if (deviceListModel.get(n).active !== currentSinks[m].active) {
                                    deviceListModel.setProperty(n, "active", currentSinks[m].active);
                                }
                                if (deviceListModel.get(n).name !== currentSinks[m].name) {
                                    deviceListModel.setProperty(n, "name", currentSinks[m].name);
                                }
                                break;
                            }
                        }
                        if (!found) {
                            deviceListModel.append(currentSinks[m]);
                        }
                    }

                    for (let k = deviceListModel.count - 1; k >= 0; k--) {
                        let keep = false;
                        for (let j = 0; j < currentSinks.length; j++) {
                            if (currentSinks[j].devId === deviceListModel.get(k).devId) {
                                keep = true;
                                break;
                            }
                        }
                        if (!keep) {
                            deviceListModel.remove(k);
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: changeDeviceProcess
        running: false
        function switchSink(sinkId) {
            command = ["wpctl", "set-default", sinkId];
            running = true;
        }
    }

    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            audioRoot.menuOpen = false;
        }
    }

    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        popupCard.targetX = -655;
        popupCard.targetOpacity = 0.0;

        rootScope.requestOpen(globalVolumeModal);
        menuOpen = true;

        slideInAnimation.start();
        syncDevicesQuery.running = false;
        syncDevicesQuery.running = true;
        checkUserActivity();
    }

    function closeMenu(): void {
        popupCard.targetX = -655;
        popupCard.targetOpacity = 0.0;
        closeTimer.start();
    }

    function checkUserActivity() {
        if (globalVolumeSlider.pressed || cardHoverTracker.containsMouse || sliderHoverTracker.containsMouse || listContainerMouse.containsMouse) {
            osdAutohideTimer.stop(); 
        } else {
            osdAutohideTimer.restart(); 
        }
    }

    ListModel {
        id: deviceListModel
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== globalVolumeModal && menuOpen) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: volumeHitbox
        anchors.fill: parent
        color: volumeMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 0 

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                id: volumeIcon
                Layout.alignment: Qt.AlignHCenter
                text: (audioRoot.isMuted || audioRoot.currentVol <= 0.01) ? "volume_off" : (audioRoot.currentVol > 0.50 ? "volume_up" : "volume_down")
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: "#ffffff" 
            }
        }

        MouseArea {
            id: volumeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: globalVolumeModal
        visible: audioRoot.menuOpen
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && audioRoot.menuOpen) {
                popupCard.forceActiveFocus();
            }
        }

        MouseArea { 
            anchors.fill: parent
            onClicked: closeMenu() 
        }

        Process {
            id: adjustVolume
            command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", globalVolumeSlider.value.toFixed(2)]
            running: false
        }

        Rectangle {
            id: popupCard
            width: 300
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 12
            property int targetX: -655
            property real targetOpacity: 0.0
            anchors.leftMargin: targetX
            opacity: targetOpacity

            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupCard; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupCard; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            color: "#9911111b" 
            border.width: 0
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: 0
            bottomRightRadius: 0
            height: Math.min(146 + (deviceListModel.count * 40), 300)
            focus: true
            
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            Component.onCompleted: popupCard.forceActiveFocus()

            Behavior on height {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                id: cardHoverTracker
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: checkUserActivity()
            }

            MouseArea {
                anchors.fill: parent
                onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
            }

            Text {
                id: titleLabel
                text: "Audio"
                font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; 
                color: "#ffffff" 
                x: 14; y: 14
            }

            Rectangle {
                id: headerDivider
                width: parent.width - 24; height: 1; color: "#26ffffff"
                x: 12; y: 44
            }

            Slider {
                id: globalVolumeSlider
                width: parent.width - 64; height: 32
                x: 12; y: 54
                orientation: Qt.Horizontal
                from: 0.0
                to: 1.0
                value: 0.0

                onPressedChanged: checkUserActivity()
                onMoved: {
                    adjustVolume.running = false;
                    adjustVolume.running = true;
                    checkUserActivity();
                }

                background: Rectangle {
                    height: 3; radius: 0; color: "#26ffffff"
                    width: globalVolumeSlider.availableWidth
                    x: globalVolumeSlider.leftPadding
                    y: globalVolumeSlider.topPadding + globalVolumeSlider.availableHeight / 2 - height / 2

                    Rectangle {
                        height: parent.height
                        width: globalVolumeSlider.visualPosition * parent.width
                        color: "#ffffff" 
                        radius: 0
                    }
                }

                handle: Rectangle {
                    width: 16; height: 16; radius: 8; color: "#ffffff" 
                    x: globalVolumeSlider.leftPadding + globalVolumeSlider.visualPosition * (globalVolumeSlider.availableWidth - width)
                    y: globalVolumeSlider.topPadding + globalVolumeSlider.availableHeight / 2 - height / 2

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.NoButton 
                    }
                }

                MouseArea {
                    id: sliderHoverTracker
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton 
                    onContainsMouseChanged: checkUserActivity()
                }
            }

            Text {
                text: Math.round(globalVolumeSlider.value * 100) + "%"
                font.family: "Rubik"; font.pixelSize: 12; font.bold: true; color: "#ffffff"
                anchors.verticalCenter: globalVolumeSlider.verticalCenter
                anchors.right: parent.right; anchors.rightMargin: 14
            }

            Rectangle {
                id: sliderDivider
                width: parent.width - 24; height: 1; color: "#26ffffff"
                x: 12; y: 94
            }

            Text {
                id: outputsLabel
                text: "Outputs"
                font.family: "Rubik"; font.pixelSize: 13; font.bold: true; 
                color: "#ffffff" 
                x: 14; y: 104
            }

            Item {
                id: listContainer
                width: parent.width - 24
                x: 12
                anchors.top: outputsLabel.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.bottomMargin: 12

                MouseArea {
                    id: listContainerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: checkUserActivity()
                }

                ListView {
                    id: deviceListView
                    anchors.fill: parent
                    model: deviceListModel
                    clip: true
                    spacing: 4

                    delegate: Item {
                        width: deviceListView.width
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: active ? "#45ffffff" : (deviceMouse.containsMouse ? "#1affffff" : "transparent")
                            border.width: 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                spacing: 8

                                Rectangle {
                                    width: 6; height: 6; radius: 3
                                    color: active ? "#ffffff" : "transparent"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: name
                                    font.family: "Rubik"; font.pixelSize: 12
                                    color: active ? "#ffffff" : "#59ffffff" 
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: deviceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    changeDeviceProcess.switchSink(devId);
                                    syncDevicesQuery.running = false;
                                    syncDevicesQuery.running = true;
                                    checkUserActivity();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
