import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: powerRoot
    implicitWidth: powerHitbox.width
    implicitHeight: 32

    // 🧠 VISUAL STATE TRACKER
    property bool menuOpen: false

    // Smart auto-hide countdown tracker
    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    // 🎬 CLOSE FINALIZER TIMER
    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            powerRoot.menuOpen = false;
        }
    }

    // 🔓 ANIMATED CONTEXT INTERFACING
    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        // Reset hidden baseline coordinates before mapping window surface
        popupPowerWrapper.targetX = -320;
        popupPowerWrapper.targetOpacity = 0.0;

        rootScope.requestOpen("power");
        menuOpen = true;

        slideInAnimation.start();
        checkUserActivity();
    }

    function closeMenu(): void {
        // Animate out while the window layer shell surface is still active
        popupPowerWrapper.targetX = -320;
        popupPowerWrapper.targetOpacity = 0.0;
        closeTimer.start();
    }

    // Helper logic to cleanly handle user presence changes
    function checkUserActivity() {
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (menuOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    // 🔄 GLOBAL PANEL HANDOFF SWAP LISTENER
    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (menuOpen && rootScope.activeModal !== "power" && !slideInAnimation.running) {
                closeMenu();
            }
        }
    }

    // ==========================================
    // 🔋 POWER TRIGGER MODULE
    // ==========================================
    Rectangle {
        id: powerHitbox
        width: 32
        height: 32
        // Monochrome subtle alpha hover mask
        color: powerMouseArea.containsMouse || menuOpen ? "#26ffffff" : "transparent"
        radius: 0 

        Text {
            id: powerIcon
            text: "\u23FB"
            font.family: "Rubik"
            font.pixelSize: 20
            color: "#ffffff"
            anchors.centerIn: parent
        }

        MouseArea {
            id: powerMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    // ==========================================
    // 📅 MODAL WINDOW: Power Overlay
    // ==========================================
    PanelWindow {
        id: globalPowerModal
        visible: powerRoot.menuOpen

        // FULL SCREEN INTERCEPT CANVAS
        anchors.left: true
        anchors.top: true
        anchors.bottom: true
        anchors.right: true
        
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && powerRoot.menuOpen) {
                popupPowerWrapper.forceActiveFocus();
            } else if (!visible && powerRoot.menuOpen) {
                powerRoot.menuOpen = false;
                osdAutohideTimer.stop();
            }
        }

        Process {
            id: sysCmd
            running: false
        }

        // 🧠 DESKTOP AGNOSTIC REFACTOR
        function runCommand(args) {
            closeMenu();
            if (args[0] === "INTERNAL_LOCK") {
                // Hand execution chain to global user session hooks dynamically
                Quickshell.execDetached([
                    "sh", "-c", 
                    "loginctl lock-session || hyprlock || swaylock || waylock"
                ]);
            } else {
                sysCmd.command = args;
                sysCmd.running = true;
            }
        }

        // GLOBAL CAPTURE SHIELD
        MouseArea {
            anchors.fill: parent
            onPressed: (mouse) => {
                closeMenu();
                mouse.accepted = true;
            }
        }

        Rectangle {
            id: popupPowerWrapper
            
            width: 160
            height: 200
            
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            anchors.left: parent.left
            
            property int targetX: -320
            property real targetOpacity: 0.0
            
            anchors.leftMargin: targetX
            opacity: targetOpacity

            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupPowerWrapper; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupPowerWrapper; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
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
            focus: true

            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: 0
            bottomRightRadius: 0

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            Component.onCompleted: popupPowerWrapper.forceActiveFocus()
            
            MouseArea {
                id: cardHoverTracker
                anchors.fill: parent
                hoverEnabled: true
                
                onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
                onContainsMouseChanged: checkUserActivity()
            }

            // ==========================================
            // 📋 UNIFIED LAYOUT CONTAINER
            // ==========================================
            ColumnLayout {
                id: menuContentLayout
                
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { 
                        text: "Session" 
                        font.family: "Rubik"
                        font.pixelSize: 16 
                        font.weight: Font.Bold 
                        color: "#ffffff" 
                    }
                    Item { Layout.fillWidth: true }
                }

                Rectangle { 
                    Layout.fillWidth: true
                    height: 1 
                    color: "#26ffffff" 
                }

                ColumnLayout {
                    id: menuLayout
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "󰌾  Lock",     cmd: ["INTERNAL_LOCK"] },
                            { label: "󰤄  Suspend",  cmd: ["systemctl", "suspend"] },
                            { label: "󰜉  Reboot",   cmd: ["systemctl", "reboot"] },
                            { label: "󰐥  Shutdown", cmd: ["systemctl", "poweroff"] }
                        ]

                        delegate: Item {
                            Layout.fillWidth: true
                            height: 30

                            MouseArea {
                                id: menuBtn
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true

                                onClicked: globalPowerModal.runCommand(modelData.cmd)

                                Rectangle {
                                    id: btnBg
                                    anchors.fill: parent
                                    color: menuBtn.containsMouse ? "#26ffffff" : "transparent"
                                    radius: 0 

                                    Text {
                                        text: modelData.label
                                        font.family: "Rubik"
                                        font.pixelSize: 13
                                        font.weight: Font.Normal
                                        color: menuBtn.containsMouse ? "#ffffff" : "#8cffffff"
                                        anchors.verticalCenter: btnBg.verticalCenter
                                        anchors.left: btnBg.left
                                        anchors.leftMargin: 8
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
