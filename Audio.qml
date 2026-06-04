import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

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
            if (drawerTemplate.isOpen) {
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
        interval: Config.autohideInterval
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    function toggleMenu(): void {
        drawerTemplate.isOpen = !drawerTemplate.isOpen;
    }

    function closeMenu(): void {
        drawerTemplate.isOpen = false;
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
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: volumeHitbox
        anchors.fill: parent
        color: "transparent"
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                id: volumeIcon
                Layout.alignment: Qt.AlignHCenter
                text: (audioRoot.isMuted || audioRoot.currentVol <= 0.01) ? "volume_off" : (audioRoot.currentVol > 0.50 ? "volume_up" : "volume_down")
                font.family: "Material Symbols Outlined"
                font.pixelSize: 24
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
            }
        }

        Rectangle {
            id: audioHoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: volumeMouseArea.containsMouse ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: volumeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: Math.min(146 + (deviceListModel.count * 40), 300)
        modalToken: "audio"
        anchorTop: false

        onIsOpenChanged: {
            if (isOpen) {
                syncDevicesQuery.running = false;
                syncDevicesQuery.running = true;
                checkUserActivity();
            } else {
                audioRoot.menuOpen = false;
            }
        }

        Behavior on drawerHeight {
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

        Item {
            id: layoutFocusWrapper
            anchors.fill: parent
            focus: true

            Text {
                id: titleLabel
                text: "Audio"
                font.family: "Rubik"
                font.pixelSize: 16
                font.weight: Font.Bold
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                x: 14
                y: 14
            }

            Rectangle {
                id: headerDivider
                width: Config.drawerTargetWidth - 24
                height: 1
                color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                x: 12
                y: 44
            }

            Slider {
                id: globalVolumeSlider
                width: Config.drawerTargetWidth - 64
                height: 32
                x: 12
                y: 54
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
                    height: 3
                    radius: 0
                    color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                    width: globalVolumeSlider.availableWidth
                    x: globalVolumeSlider.leftPadding
                    y: globalVolumeSlider.topPadding + globalVolumeSlider.availableHeight / 2 - height / 2

                    Rectangle {
                        height: parent.height
                        width: globalVolumeSlider.visualPosition * parent.width
                        color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff" 
                        radius: 0
                    }
                }

                handle: Rectangle {
                    width: 16
                    height: 16
                    radius: 8
                    color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff" 
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
                font.family: "Rubik"
                font.pixelSize: 12
                font.bold: true
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                anchors.verticalCenter: globalVolumeSlider.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 14
            }

            Rectangle {
                id: sliderDivider
                width: Config.drawerTargetWidth - 24
                height: 1
                color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                x: 12
                y: 94
            }

            Text {
                id: outputsLabel
                text: "Outputs"
                font.family: "Rubik"
                font.pixelSize: 13
                font.bold: true
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                x: 14
                y: 104
            }

            Item {
                id: listContainer
                width: Config.drawerTargetWidth - 24
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
                            color: active ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") : (deviceMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#1affffff") : "transparent")
                            border.width: 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: active ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : "transparent"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: name
                                    font.family: "Rubik"
                                    font.pixelSize: 12
                                    color: active ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_fg : "#59ffffff") 
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

        Process {
            id: adjustVolume
            command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", globalVolumeSlider.value.toFixed(2)]
            running: false
        }
    }
}
