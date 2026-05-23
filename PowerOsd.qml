// PowerOsd.qml
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
            rootScope.dismissAll();
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
        popupPowerWrapper.targetX = -655;
        popupPowerWrapper.targetOpacity = 0.0;

        rootScope.requestOpen(globalPowerModal);
        menuOpen = true;

        slideInAnimation.start();
        checkUserActivity();
    }

    function closeMenu(): void {
        popupPowerWrapper.targetX = -655;
        popupPowerWrapper.targetOpacity = 0.0;

        closeTimer.start();
    }

    // Helper logic to cleanly handle user presence changes
    function checkUserActivity() {
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); // Interacting: Freeze dismissal rule
        } else if (globalPowerModal.visible && menuOpen) {
            osdAutohideTimer.restart(); // Left environment bounds: Start countdown ticking
        }
    }

    // ==========================================
    // 🔋 POWER TRIGGER MODULE
    // ==========================================
    Rectangle {
        id: powerHitbox
        width: 32
        height: 32
        color: powerMouseArea.containsMouse || menuOpen ? "#313244" : "transparent"
        radius: 8

        Text {
            id: powerIcon
            text: "⏻"
            font.family: "Rubik"
            font.pixelSize: 16
            color: menuOpen ? "#f38ba8" : "#a6adc8"
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
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrLayershell.OnDemand

        onVisibleChanged: {
            if (visible && powerRoot.menuOpen) {
                popupPowerWrapper.forceActiveFocus();
            }
        }

        MouseArea { 
            anchors.fill: parent; 
            onClicked: closeMenu() 
        }

        Process {
            id: sysCmd
            running: false
        }

        function runCommand(args) {
            closeMenu();
            sysCmd.command = args;
            sysCmd.running = true;
        }

        Rectangle {
            id: popupPowerWrapper
            width: 160  
            height: menuContentLayout.implicitHeight + 28
            
            // Anchored bottom-left, matching the universal axis alignment
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 12
            
            // Explicit animation targets
            property int targetX: -655
            property real targetOpacity: 0.0

            anchors.leftMargin: targetX
            opacity: targetOpacity

            // ✨ ENTRY TIMELINE SEQUENCER
            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupPowerWrapper; property: "targetX"; to: 5; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupPowerWrapper; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            // ✨ IMPLICIT EXIT MECHANISMS
            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            color: "#cc11111b" 
            border.color: "#898989" 
            border.width: 1
            radius: 12

            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            Component.onCompleted: popupPowerWrapper.forceActiveFocus()
            
            // Card base background hover region tracker
            MouseArea {
                id: cardHoverTracker
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: checkUserActivity()
            }

            // Explicitly swallow clicks targeting the container background to avoid background dismissal
            MouseArea { 
                anchors.fill: parent; 
                onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); } 
            }

            // ==========================================
            // 📋 UNIFIED LAYOUT CONTAINER
            // ==========================================
            ColumnLayout {
                id: menuContentLayout
                anchors.fill: parent
                anchors.margins: 14
                spacing: 10

                // Title Header Block
                RowLayout {
                    Layout.fillWidth: true
                    Text { 
                        text: "Session" 
                        font.family: "Rubik"
                        font.pixelSize: 16 
                        font.weight: Font.Bold 
                        color: "#cdd6f4" 
                    }
                    Item { Layout.fillWidth: true }
                }

                // Separation Accent Line
                Rectangle { 
                    Layout.fillWidth: true
                    height: 1 
                    color: "#313244" 
                }

                // Interactive Options Array
                ColumnLayout {
                    id: menuLayout
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: [
                            { label: "󰌾  Lock",     cmd: ["hyprlock"] },
                            { label: "󰤄  Suspend",  cmd: ["systemctl", "suspend"] },
                            { label: "󰜉  Reboot",   cmd: ["systemctl", "reboot"] },
                            { label: "󰐥  Shutdown", cmd: ["systemctl", "poweroff"] }
                        ]

                        delegate: MouseArea {
                            id: menuBtn
                            Layout.fillWidth: true
                            implicitHeight: 30
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true

                            onClicked: globalPowerModal.runCommand(modelData.cmd)

                            Rectangle {
                                id: btnBg
                                anchors.fill: parent
                                color: menuBtn.containsMouse ? "#313244" : "transparent"
                                radius: 6

                                Text {
                                    text: modelData.label
                                    font.family: "Rubik"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: menuBtn.containsMouse ? "#cdd6f4" : "#a6adc8"
                                    
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
