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
            fadeOutAnimation.start();
        }
    }

    // 🎬 ANIMATION OUTRO FINALIZER
    SequentialAnimation {
        id: fadeOutAnimation
        NumberAnimation { target: innerContentCard; property: "opacity"; to: 0.0; duration: 120; easing.type: Easing.OutQuad }
        PropertyAction { 
            target: hudWindowSurface; 
            property: "WlrLayershell.layer"; 
            // 🎯 THE FIX: Sends the idle window to the bottom of the stack to keep click-through fully interactive
            value: WlrLayer.Background 
        }
        PropertyAction { target: hudRoot; property: "visibleActive"; value: false }
    }

    function triggerHudPopup(newVol, muteState) {
        hudRoot.volumeLevel = newVol;
        hudRoot.isMuted = muteState;
        
        if (!hudRoot.visibleActive && !rootScope.audioSliderActive) {
            fadeOutAnimation.stop();
            
            // 🎯 THE FIX: Instantly lift back to the top overlay layer before executing the fade pass
            hudWindowSurface.WlrLayershell.layer = WlrLayer.Overlay;
            
            innerContentCard.opacity = 0.0;
            hudRoot.visibleActive = true;
            fadeInAnimation.start();
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
        
        // 🎯 THE FIX: Visible stays permanently true. Unmapping routines are completely bypassed 
        // to prevent Hyprland's birth-frame alpha checks from occasionally failing.
        visible: true
        screen: hudRoot.targetScreen ? hudRoot.targetScreen : screen
        
        implicitWidth: 48
        implicitHeight: 200
        
        anchors.left: true
        anchors.top: false
        anchors.bottom: false
        anchors.right: false

        color: "transparent"
        
        // Initializes as a background layer until an active audio pulse triggers it
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        // 📐 POSITIONING MATRIX: 54px (bar width) + 12px (bar gap) = 66px left margin offset
        WlrLayershell.margins.left: 66
        WlrLayershell.margins.right: 0
        WlrLayershell.margins.bottom: 0
        WlrLayershell.margins.top: hudWindowSurface.screen ? (hudWindowSurface.screen.height / 2) - 100 : 0

        // ✨ ENTRY SEQUENCE
        SequentialAnimation {
            id: fadeInAnimation
            NumberAnimation { target: innerContentCard; property: "opacity"; to: 1.0; duration: 100; easing.type: Easing.OutQuad }
            PropertyAction { target: dismissTimer; property: "running"; value: true }
        }

        Rectangle {
            id: innerContentCard
            anchors.fill: parent
            color: "#9911111b"
            border.width: 0
            opacity: 0.0

            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: 0
            bottomRightRadius: 0

            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

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
                    radius: 0 
                    clip: true

                    Rectangle {
                        id: barFill
                        width: parent.width
                        height: parent.height * Math.min(hudRoot.volumeLevel, 1.0)
                        color: hudRoot.isMuted ? "#f38ba8" : "#cdd6f4"
                        radius: 0 
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
