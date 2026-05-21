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
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            if (!globalVolumeSlider.pressed) {
                syncVolumeQuery.running = false;
                syncVolumeQuery.running = true;
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
                                globalVolumeSlider.value = volVal;
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // ⏱️ Auto-Hide Timer (Dismisses the OSD after 2 seconds of inactivity)
    Timer {
        id: osdAutohideTimer
        interval: 2000
        running: false
        repeat: false
        onTriggered: globalVolumeModal.visible = false
    }

    // ⚡ Automated Visibility Trigger
    Connections {
        target: globalVolumeSlider
        
        function onValueChanged() {
            if (!globalVolumeSlider.pressed) {
                globalVolumeModal.visible = true;
                osdAutohideTimer.restart();
            }
        }
    }

    // ==========================================
    // 🔊 AUDIO ICON TOGGLE INDICATOR MODULE
    // ==========================================
    Rectangle {
        id: volumeHitbox
        anchors.fill: parent
        color: volumeMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        Text {
            id: volumeIcon
            text: {
                if (audioRoot.isMuted || audioRoot.currentVol <= 0.01) return "\uE04F";
                if (audioRoot.currentVol > 0.50)  return "\uE050";
                return "\uE04D";
            }
            font.family: "Material Design Icons"
            font.pixelSize: 26
            color: volumeMouseArea.containsMouse ? "#afbaff" : "#cdd6f4"
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
                if (globalVolumeModal.visible) osdAutohideTimer.restart();
            }
        }
    }

    // ==========================================
    // 🎚️ MODAL WINDOW: Volume Slider Container
    // ==========================================
    PanelWindow {
        id: globalVolumeModal
        visible: false
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"

        MouseArea { anchors.fill: parent; onClicked: globalVolumeModal.visible = false }

        Process {
            id: adjustVolume
            command: ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", globalVolumeSlider.value.toFixed(2)]
            running: false
        }

        Rectangle {
            id: popupCard
            width: 120
            height: 280
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 40
            anchors.rightMargin: 10 
            color: "transparent"       
            border.width: 0           
            radius: 8

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    mouse.accepted = true;
                    osdAutohideTimer.restart();
                }
            }

            Slider {
                id: globalVolumeSlider
                anchors.fill: parent
                anchors.margins: 12
                orientation: Qt.Vertical
                from: 0.0
                to: 1.0
                value: 0.0
                
                onMoved: {
                    adjustVolume.running = false;
                    adjustVolume.running = true;
                    osdAutohideTimer.restart();
                }

                background: Rectangle {
                    width: 6
                    implicitHeight: 180
                    x: globalVolumeSlider.leftPadding + (globalVolumeSlider.availableWidth / 2) - (width / 2) + 20
                    y: globalVolumeSlider.topPadding
                    radius: 3
                    color: "#313244"

                    Rectangle {
                        width: parent.width
                        height: (1.0 - globalVolumeSlider.visualPosition) * parent.height
                        anchors.bottom: parent.bottom
                        color: "#cdd6f4"
                        radius: 3
                    }
                }

                handle: Rectangle {
                    id: sliderHandle
                    width: 22
                    height: 22
                    x: globalVolumeSlider.leftPadding + (globalVolumeSlider.availableWidth / 2) - (width / 2) + 20
                    y: globalVolumeSlider.topPadding + globalVolumeSlider.visualPosition * (globalVolumeSlider.availableHeight - height)
                    radius: 11
                    color: "#f5e0dc"

                    Text {
                        id: percentageText
                        text: Math.round(globalVolumeSlider.value * 100) + "%"
                        font.family: "Rubik"
                        font.pixelSize: 16
                        font.weight: Font.Bold
                        color: "#cdd6f4"
                        anchors.right: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: 12 
                    }
                }
            }
        }
    }
}
