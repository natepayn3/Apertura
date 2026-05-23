import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: hudRoot
    
    property real volumeLevel: 0.0
    property bool isMuted: false
    property bool visibleActive: false

    property var targetScreen: null

    // 🕒 2-SECOND DISMISSAL TIMER
    Timer {
        id: dismissTimer
        interval: 2000
        repeat: false
        onTriggered: {
            slideOutAnimation.start();
        }
    }

    // 🎬 ANIMATION OUTRO FINALIZER
    SequentialAnimation {
        id: slideOutAnimation
        ParallelAnimation {
            NumberAnimation { target: hudCardFrame; property: "targetX"; to: -48; duration: 150; easing.type: Easing.OutCubic }
            NumberAnimation { target: hudCardFrame; property: "targetOpacity"; to: 0.0; duration: 120; easing.type: Easing.OutQuad }
        }
        PropertyAction { target: hudRoot; property: "visibleActive"; value: false }
    }

    function triggerHudPopup(newVol, muteState) {
        hudRoot.volumeLevel = newVol;
        hudRoot.isMuted = muteState;
        
        if (!hudRoot.visibleActive) {
            slideOutAnimation.stop();
            hudCardFrame.targetX = -48;
            hudCardFrame.targetOpacity = 0.0;
            hudRoot.visibleActive = true;
            slideInAnimation.start();
        } else {
            dismissTimer.restart();
        }
    }

    // Ticking driver to poll wpctl status
    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            hudVolumeWatcher.running = false;
            hudVolumeWatcher.running = true;
        }
    }

    // 📡 HARDWARE SYNC LOOP
    Process {
        id: hudVolumeWatcher
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        running: true
        
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let cleaned = text.trim();
                    if (cleaned.startsWith("Volume:")) {
                        let muteState = cleaned.includes("[MUTED]");
                        let parts = cleaned.split(" ");
                        if (parts.length >= 2) {
                            let volVal = parseFloat(parts[1]);
                            if (!isNaN(volVal)) {
                                if (Math.abs(hudRoot.volumeLevel - volVal) > 0.001 || hudRoot.isMuted !== muteState) {
                                    hudRoot.triggerHudPopup(volVal, muteState);
                                }
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    // ==========================================
    // 🪟 NATIVE HUD WINDOW SURFACE
    // ==========================================
    PanelWindow {
        id: hudWindowSurface
        visible: hudRoot.visibleActive
        
        screen: hudRoot.targetScreen

        width: 48
        
        anchors.left: true
        anchors.top: true
        anchors.bottom: true
        
        margins.left: 70

        WlrLayershell.margins.top: hudRoot.targetScreen ? (hudRoot.targetScreen.height / 2) - 100 : 0
        WlrLayershell.margins.bottom: hudRoot.targetScreen ? (hudRoot.targetScreen.height / 2) - 100 : 0
        
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-hud"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        WlrLayershell.exclusiveZone: -1
        mask: Region {}

        Rectangle {
            id: hudCardFrame
            
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width
            
            property int targetX: -48
            property real targetOpacity: 0.0
            
            x: targetX
            opacity: targetOpacity

            // ✨ ENTRY TRANSLATION TIMELINE
            SequentialAnimation {
                id: slideInAnimation
                ParallelAnimation {
                    NumberAnimation { target: hudCardFrame; property: "targetX"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                    NumberAnimation { target: hudCardFrame; property: "targetOpacity"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                }
                PropertyAction { target: dismissTimer; property: "running"; value: true }
            }

            color: "#cc11111b"
            border.color: "#313244"
            border.width: 1
            radius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                // 🔊 PROGRESS BAR TRACK
                Rectangle {
                    id: barTrack
                    Layout.preferredWidth: 10
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter
                    color: "#313244"
                    radius: 5
                    clip: true

                    Rectangle {
                        id: barFill
                        width: parent.width
                        height: parent.height * Math.min(hudRoot.volumeLevel, 1.0)
                        
                        // 🔒 FIXED: Changed active state color filling from #74c7ec (blue) to #cdd6f4 (text lavender/white)
                        color: hudRoot.isMuted ? "#f38ba8" : "#cdd6f4"
                        radius: 5
                        
                        anchors.bottom: parent.bottom

                        Behavior on height {
                            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                        }
                    }
                }

                // 🔢 RUNTIME STATE DATA
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: Math.round(hudRoot.volumeLevel * 100) + "%"
                        font.family: "Rubik"
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: hudRoot.isMuted ? "#f38ba8" : "#cdd6f4"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: hudRoot.isMuted ? "󰝟" : (hudRoot.volumeLevel > 0.50 ? "󰕾" : "󰖀")
                        font.family: "Material Design Icons"
                        font.pixelSize: 22
                        color: hudRoot.isMuted ? "#f38ba8" : "#a6adc8"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}