import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Item {
    id: batRoot
    
    property bool isLaptop: false
    property string acPath: ""
    
    implicitWidth: isLaptop ? 32 : 0
    implicitHeight: isLaptop ? 32 : 0
    visible: isLaptop

    property int capacity: 100
    property bool isCharging: false
    property bool menuOpen: false

    Process {
        id: presenceCheck
        command: ["sh", "-c", "if [ -f /sys/class/power_supply/BAT1/capacity ]; then echo 1; fi"]
        running: true
        
        stdout: StdioCollector {
            onTextChanged: {
                if (text.trim() === "1") {
                    batRoot.isLaptop = true;
                    acPathCheck.running = true;
                } else {
                    batRoot.isLaptop = false;
                }
            }
        }
    }

    Process {
        id: acPathCheck
        command: ["sh", "-c", "if [ -f /sys/class/power_supply/AC/online ]; then echo '/sys/class/power_supply/AC/online'; else echo '/sys/class/power_supply/ADP1/online'; fi"]
        running: false
        
        stdout: StdioCollector {
            onTextChanged: {
                let path = text.trim();
                if (path) {
                    batRoot.acPath = path;
                    capReader.reload();
                    acReader.reload();
                }
            }
        }
    }

    FileView {
        id: capReader
        path: batRoot.isLaptop ? "/sys/class/power_supply/BAT1/capacity" : ""
        onTextChanged: {
            if (capReader.text) {
                let cleanText = capReader.text().trim();
                if (cleanText.length > 0) {
                    batRoot.capacity = parseInt(cleanText) || 100;
                }
            }
        }
    }

    FileView {
        id: acReader
        path: (batRoot.isLaptop && batRoot.acPath) ? batRoot.acPath : ""
        onTextChanged: {
            if (acReader.text) {
                let cleanStatus = acReader.text().trim();
                batRoot.isCharging = (cleanStatus === "1");
            }
        }
    }

    Timer {
        interval: 1000
        running: batRoot.isLaptop
        repeat: true
        onTriggered: {
            capReader.reload();
            acReader.reload();
        }
    }

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
        if (batteryMouseArea.containsMouse || cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else {
            osdAutohideTimer.restart(); 
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: batteryHitbox
        anchors.fill: parent
        color: "transparent"
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                id: batteryIcon
                Layout.alignment: Qt.AlignHCenter
                
                text: batteryMouseArea.containsMouse ? batRoot.capacity + "%" : (
                    batRoot.isCharging        ? "battery_android_frame_bolt" : 
                    batRoot.capacity >= 95    ? "battery_android_full" :
                    batRoot.capacity < 15     ? "battery_android_0" :
                    batRoot.capacity < 30     ? "battery_android_1" : 
                    batRoot.capacity < 45     ? "battery_android_2" : 
                    batRoot.capacity < 60     ? "battery_android_3" : 
                    batRoot.capacity < 75     ? "battery_android_4" : 
                    batRoot.capacity < 90     ? "battery_android_5" : 
                                                "battery_android_6"
                )
                                                    
                font.family: batteryMouseArea.containsMouse ? "Rubik" : "Material Symbols Outlined" 
                font.pixelSize: batteryMouseArea.containsMouse ? 12 : 20
                font.weight: batteryMouseArea.containsMouse ? Font.Bold : Font.Normal
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Rectangle {
            id: batteryHoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: batteryMouseArea.containsMouse ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: batteryMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
            onContainsMouseChanged: checkUserActivity()
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 96
        modalToken: "battery"
        anchorTop: false

        onIsOpenChanged: {
            if (isOpen) {
                checkUserActivity();
            } else {
                batRoot.menuOpen = false;
            }
        }

        MouseArea {
            id: cardHoverTracker
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: checkUserActivity()
            onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); } 
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            focus: true

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Battery"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                Item { Layout.fillWidth: true }
                Text { 
                    text: batRoot.isCharging ? (batRoot.capacity >= 99 ? "Fully Charged" : "󱐋 Charging") : "Discharging"
                    font.family: "Rubik"; font.pixelSize: 12
                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff" }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Current Charge:"; font.family: "Rubik"; font.pixelSize: 13; color: rootScope.theme ? Qt.alpha(rootScope.theme.theme_fg, 0.35) : "#59ffffff" }
                    Item { Layout.fillWidth: true }
                    
                    RowLayout {
                        spacing: 6
                        Text {
                            text: batRoot.isCharging        ? "battery_android_frame_bolt" : 
                                  batRoot.capacity >= 95    ? "battery_android_full" :
                                  batRoot.capacity < 15     ? "battery_android_0" :
                                  batRoot.capacity < 30     ? "battery_android_1" : 
                                  batRoot.capacity < 45     ? "battery_android_2" : 
                                  batRoot.capacity < 60     ? "battery_android_3" : 
                                  batRoot.capacity < 75     ? "battery_android_4" : 
                                  batRoot.capacity < 90     ? "battery_android_5" : 
                                                              "battery_android_6"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 20
                            color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff"
                        }
                        Text { 
                            text: batRoot.capacity + "%"
                            font.family: "Rubik"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                        }
                    }
                }
            }
        }
    }
}
