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

    property bool menuOpen: false
    property bool windowAlive: false

    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        rootScope.requestOpen("power");
        windowAlive = true;
        menuOpen = true;
        checkUserActivity();
    }

    function closeMenu(): void {
        menuOpen = false;
    }

    function checkUserActivity() {
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (menuOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (menuOpen && rootScope.activeModal !== "power") {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: powerHitbox
        width: 32
        height: 32
        color: powerMouseArea.containsMouse || menuOpen ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
        radius: 0 

        Text {
            id: powerIcon
            text: "power_settings_new"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 16
            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
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

    PanelWindow {
        id: globalPowerModal
        visible: powerRoot.windowAlive
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
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

        function runCommand(args) {
            if (args[0] === "INTERNAL_LOCK") {
                powerRoot.menuOpen = false;
                osdAutohideTimer.stop();
                
                Quickshell.execDetached([
                    "sh", "-c", 
                    "hyprlock"
                ]);
            } else {
                closeMenu();
                sysCmd.command = args;
                sysCmd.running = true;
            }
        }

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

            states: [
                State {
                    name: "visible"
                    when: powerRoot.menuOpen
                    PropertyChanges { target: popupPowerWrapper; x: 0; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: !powerRoot.menuOpen
                    PropertyChanges { target: popupPowerWrapper; x: -180; opacity: 0.0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "visible"
                    ParallelAnimation {
                        NumberAnimation { property: "x"; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.OutCubic }
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { property: "x"; duration: 350; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.InCubic }
                        }
                        ScriptAction {
                            script: { powerRoot.windowAlive = false; }
                        }
                    }
                }
            ]

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
                        color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                    }
                    Item { Layout.fillWidth: true }
                }

                Rectangle { 
                    Layout.fillWidth: true
                    height: 1 
                    color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff" 
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
                                    color: menuBtn.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
                                    radius: 0 

                                    Text {
                                        text: modelData.label
                                        font.family: "Rubik"
                                        font.pixelSize: 13
                                        font.weight: Font.Normal
                                        color: menuBtn.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_fg : "#8cffffff")
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
