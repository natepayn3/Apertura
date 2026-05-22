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

    // 🔄 AUDIO BACKGROUND LOOP
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

    // Volume status parser
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
                                globalVolumeSlider.value = volVal;
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // 🎧 SINK/OUTPUT DEVICE PARSER
    Process {
        id: syncDevicesQuery
        command: ["wpctl", "status"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let lines = text.split("\n");
                    let parsingSinks = false;
                    
                    deviceListModel.clear();

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

                                deviceListModel.append({
                                    "devId": devId,
                                    "name": cleanName,
                                    "active": isActive
                                });
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // Target default audio sink router
    Process {
        id: changeDeviceProcess
        running: false
        function switchSink(sinkId) {
            command = ["wpctl", "set-default", sinkId];
            running = true;
        }
    }

    // Smart auto-hide countdown tracker
    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: globalVolumeModal.visible = false
    }

    // Helper logic to cleanly handle user presence changes
    function checkUserActivity() {
        if (globalVolumeSlider.pressed || cardHoverTracker.containsMouse || sliderHoverTracker.containsMouse || listHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (globalVolumeModal.visible) {
            osdAutohideTimer.restart(); 
        }
    }

    ListModel {
        id: deviceListModel
    }

    // 🔊 AUDIO ICON PANEL TRIGGER
    Rectangle {
        id: volumeHitbox
        anchors.fill: parent
        color: volumeMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        Text {
            id: volumeIcon
            text: (audioRoot.isMuted || audioRoot.currentVol <= 0.01) ? "\uE04F" : (audioRoot.currentVol > 0.50 ? "\uE050" : "\uE04D")
            font.family: "Material Design Icons"
            font.pixelSize: 26
            color: "#cdd6f4" 
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 3
        }

        MouseArea {
            id: volumeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                globalVolumeModal.visible = !globalVolumeModal.visible;
                if (globalVolumeModal.visible) {
                    syncDevicesQuery.running = false;
                    syncDevicesQuery.running = true;
                    checkUserActivity();
                }
            }
        }
    }

    // 🎚️ MIXER CONTEXT CONTAINER
    PanelWindow {
        id: globalVolumeModal
        visible: false
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrLayershell.OnDemand

        onVisibleChanged: {
            if (visible) {
                popupCard.forceActiveFocus();
            }
        }

        Connections {
            target: Quickshell.window
            function onActiveChanged() {
                if (!Quickshell.window.active && globalVolumeModal.visible) {
                    globalVolumeModal.visible = false;
                }
            }
        }

        // Global background click dismiss layer
        MouseArea { 
            anchors.fill: parent
            onClicked: globalVolumeModal.visible = false 
        }

        Process {
            id: adjustVolume
            command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", globalVolumeSlider.value.toFixed(2)]
            running: false
        }

        Rectangle {
            id: popupCard
            width: 300
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 5
            anchors.rightMargin: 12
            
            color: "#cc11111b" // 🎯 MATCHED: 80% opacity glass profile
            border.color: "#898989" 
            border.width: 1
            radius: 12

            height: Math.min(146 + (deviceListModel.count * 40), 300)

            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    globalVolumeModal.visible = false;
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

            // Card base background hover region tracker
            MouseArea {
                id: cardHoverTracker
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: checkUserActivity()
            }

            // Explicitly swallow clicks targeting the container background to avoid background dismissal
            MouseArea {
                anchors.fill: parent
                onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
            }

            // ==========================================
            // 🏷️ ABSOLUTE ANCHORED GEOMETRY BLOCK
            // ==========================================
            Text {
                id: titleLabel
                text: "Audio"
                font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; 
                color: "#cdd6f4" // 🔒 FIXED: Upgraded text luminosity alignment to match Calendar title
                x: 14; y: 14
            }

            Rectangle {
                id: headerDivider
                width: parent.width - 24; height: 1; color: "#313244"
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
                    height: 6; radius: 3; color: "#313244"
                    width: globalVolumeSlider.availableWidth
                    x: globalVolumeSlider.leftPadding
                    y: globalVolumeSlider.topPadding + globalVolumeSlider.availableHeight / 2 - height / 2

                    Rectangle {
                        height: parent.height
                        width: globalVolumeSlider.visualPosition * parent.width
                        color: "#898989" // 🔒 FIXED: Swapped filled track from purple to framework accent tone
                        radius: 3
                    }
                }

                handle: Rectangle {
                    width: 16; height: 16; radius: 8; color: "#cdd6f4" 
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

            // Volume Percentage Badge
            Text {
                text: Math.round(globalVolumeSlider.value * 100) + "%"
                font.family: "Rubik"; font.pixelSize: 12; font.bold: true; color: "#cdd6f4"
                anchors.verticalCenter: globalVolumeSlider.verticalCenter
                anchors.right: parent.right; anchors.rightMargin: 14
            }

            Rectangle {
                id: sliderDivider
                width: parent.width - 24; height: 1; color: "#313244"
                x: 12; y: 94
            }

            Text {
                id: outputsLabel
                text: "Outputs"
                font.family: "Rubik"; font.pixelSize: 13; font.bold: true; 
                color: "#cdd6f4" // 🔒 FIXED: Upgraded text luminosity alignment to match Calendar title
                x: 14; y: 104
            }

            // 🎧 SCROLLABLE LIST VIEWPORT
            Item {
                id: listContainer
                width: parent.width - 24
                x: 12
                anchors.top: outputsLabel.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.bottomMargin: 12

                ListView {
                    id: deviceListView
                    anchors.fill: parent
                    model: deviceListModel
                    clip: true
                    spacing: 4

                    delegate: Rectangle {
                        width: deviceListView.width
                        height: 36
                        radius: 6
                        color: active ? "#313244" : (deviceMouse.containsMouse ? "#252538" : "transparent")
                        border.color: active ? "#898989" : "transparent" // 🔒 FIXED: Set frame border highlight to gray tone vector
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                width: 6; height: 6; radius: 3
                                color: active ? "#a6e3a1" : "transparent"
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Text {
                                text: name
                                font.family: "Rubik"; font.pixelSize: 12
                                color: active ? "#cdd6f4" : "#a6adc8" // 🔒 FIXED: Active text stays foreground-stabilized, non-active tracks to subtext gray
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

                MouseArea {
                    id: listHoverTracker
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true 
                    onContainsMouseChanged: checkUserActivity()
                    onPressed: (mouse) => {
                        checkUserActivity();
                        mouse.accepted = false; 
                    }
                }
            }
        }
    }
}