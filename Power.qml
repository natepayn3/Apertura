import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Item {
    id: powerRoot
    implicitWidth: powerHitbox.width
    implicitHeight: 32

    property bool menuOpen: false

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
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (drawerTemplate.isOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (drawerTemplate.isOpen && rootScope.activeModal !== drawerTemplate.modalToken) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: powerHitbox
        width: 32
        height: 32
        color: "transparent"
        radius: 0

        Text {
            id: powerIcon
            text: "power_settings_new"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
            anchors.centerIn: parent
        }

        Rectangle {
            id: powerHoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            // Use both MouseArea and isOpen state for the tint
            opacity: (powerMouseArea.containsMouse || drawerTemplate.isOpen) ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: powerMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 200
        drawerWidth: 160
        modalToken: "power"
        anchorTop: false

        onIsOpenChanged: {
            if (isOpen) {
                powerRoot.menuOpen = true;
                checkUserActivity();
                mainContainerLayout.forceActiveFocus();
            } else {
                powerRoot.menuOpen = false;
                osdAutohideTimer.stop();
            }
        }

        function runCommand(args) {
            if (args[0] === "INTERNAL_LOCK") {
                drawerTemplate.isOpen = false;
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
            id: cardHoverTracker
            anchors.fill: parent
            hoverEnabled: true
            onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
            onContainsMouseChanged: checkUserActivity()
        }

        ColumnLayout {
            id: mainContainerLayout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            focus: true

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
                            onClicked: drawerTemplate.runCommand(modelData.cmd)

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

        Process {
            id: sysCmd
            running: false
        }
    }
}
