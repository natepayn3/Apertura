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
            value: WlrLayer.Background 
        }
        PropertyAction { target: hudRoot; property: "visibleActive"; value: false }
    }

    function triggerHudPopup(newVol, muteState) {
        hudRoot.volumeLevel = newVol;
        hudRoot.isMuted = muteState;
        
        if (!hudRoot.visibleActive && !rootScope.audioSliderActive) {
            fadeOutAnimation.stop();
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
        visible: true
        screen: hudRoot.targetScreen ? hudRoot.targetScreen : screen
        
        implicitWidth: 48
        implicitHeight: 200
        
        anchors.left: true
        anchors.top: false
        anchors.bottom: false
        anchors.right: false

        color: "transparent"
        
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
                spacing: 8
                
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                anchors.topMargin: 16
                anchors.bottomMargin: 16

                // THE TRACK
                Rectangle {
                    id: barTrack
                    Layout.preferredWidth: 4
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignHCenter
                    // Muted background channel
                    color: "#26ffffff"
                    radius: 0
                    clip: true

                    // THE FILL
                    Rectangle {
                        id: barFill
                        width: parent.width
                        height: parent.height * Math.min(hudRoot.volumeLevel, 1.0)
                        // 🎯 THE FIX: Active = Solid White (#ffffff), Muted = Low alpha opacity step (#59ffffff)
                        color: hudRoot.isMuted ? "#59ffffff" : "#ffffff"
                        anchors.bottom: parent.bottom

                        bottomLeftRadius: 0
                        bottomRightRadius: 0
                        topLeftRadius: 0
                        topRightRadius: 0

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
                        // Text channels respond with matching monochrome states
                        color: hudRoot.isMuted ? "#59ffffff" : "#ffffff"
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: hudRoot.isMuted ? "󰝟" : (hudRoot.volumeLevel > 0.50 ? "󰕾" : "󰖀")
                        font.family: "Material Design Icons"
                        font.pixelSize: 22
                        color: hudRoot.isMuted ? "#59ffffff" : "#ffffff"
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }
        }
    }
}
