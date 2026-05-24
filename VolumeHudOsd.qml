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
        
        // 🔒 FIXED: Read the master slider interlock from rootScope.
        // If you are actively dragging the slider, the OSD will remain hidden.
        if (!hudRoot.visibleActive && !rootScope.audioSliderActive) {
            slideOutAnimation.stop();
            hudCardFrame.targetX = -48;
            hudCardFrame.targetOpacity = 0.0;
            hudRoot.visibleActive = true;
            slideInAnimation.start();
        } else if (hudRoot.visibleActive && !rootScope.audioSliderActive) {
            dismissTimer.restart();
        }
    }

    // Ticking driver to poll wpctl status safely in user-space
    Timer {
        id: pollTimer
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            hudVolumeWatcher.running = false;
            hudVolumeWatcher.running = true;
        }
    }

    // 📡 UNIVERSAL PRIVILEGE-FREE SYNC LOOP
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
        
        // Match the module canvas layers
        anchors.left: true
        anchors.top: true
        anchors.bottom: true
        anchors.right: true

        // 🧠 CHROMATIC SHIFT: 0.4% alpha background pushes compositor edge blur calculations completely off-screen
        color: "#0111111b"
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-hud"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        // 📐 HARDWARE COORD ANCHOR: 54px (bar width) + 12px (bar margin gap) = 66px offset from display edge
        WlrLayershell.margins.left: 66
        WlrLayershell.margins.right: 0
        WlrLayershell.margins.bottom: 0
        WlrLayershell.margins.top: 0

        Rectangle {
            id: hudCardFrame
            
            width: 48
            height: 200
            
            anchors.left: parent.left
            anchors.top: parent.top
            
            // Replaced the static layer shell offsets with standard vertical centering matrix math
            anchors.topMargin: hudRoot.targetScreen ? (hudRoot.targetScreen.height / 2) - 100 : 0
            
            property int targetX: -48
            property real targetOpacity: 0.0
            
            // Direct mapping back to target variables for clean 0px resting state
            anchors.leftMargin: targetX
            opacity: targetOpacity

            SequentialAnimation {
                id: slideInAnimation
                ParallelAnimation {
                    // Slide animation lands securely at target 0 positioning flush with the bar boundary
                    NumberAnimation { target: hudCardFrame; property: "targetX"; to: 0; duration: 150; easing.type: Easing.OutCubic }
                    NumberAnimation { target: hudCardFrame; property: "targetOpacity"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
                }
                PropertyAction { target: dismissTimer; property: "running"; value: true }
            }

            // 🎨 MATCHED CARD STYLING: Borders removed completely, background opacity mapped to #9911111b
            color: "#9911111b"
            border.width: 0

            // 📐 GRANULAR CORNER CLIP: Left side corners squared flat flush to the system bar panel boundary
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: 12
            bottomRightRadius: 12

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

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
                        color: hudRoot.isMuted ? "#f38ba8" : "#cdd6f4"
                        radius: 5
                        anchors.bottom: parent.bottom

                        Behavior on height {
                            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                        }
                    }
                }

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
