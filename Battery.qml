import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

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
    property bool windowAlive: false

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
        rootScope.requestOpen("battery");
        windowAlive = true;
        menuOpen = true;
        checkUserActivity();
    }

    function closeMenu(): void {
        menuOpen = false;
    }

    function checkUserActivity() {
        if (batteryMouseArea.containsMouse || cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else {
            osdAutohideTimer.restart(); 
        }
    }

    Rectangle {
        id: batteryHitbox
        anchors.fill: parent
        color: batteryMouseArea.containsMouse ? "#26ffffff" : "transparent"
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
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
            }
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

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== "battery" && menuOpen) {
                closeMenu();
            }
        }
    }

    PanelWindow {
        id: batteryOverlayModal
        visible: batRoot.windowAlive
        color: "transparent"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && batRoot.menuOpen) {
                popupMenuFrame.forceActiveFocus();
            }
        }

        MouseArea { 
            anchors.fill: parent
            onClicked: closeMenu()
        }

        Rectangle {
            id: popupMenuFrame
            width: 300; height: 96 
            anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            
            states: [
                State {
                    name: "visible"
                    when: batRoot.menuOpen
                    PropertyChanges { target: popupMenuFrame; x: 0; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: !batRoot.menuOpen
                    PropertyChanges { target: popupMenuFrame; x: -320; opacity: 0.0 }
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
                            script: { batRoot.windowAlive = false; }
                        }
                    }
                }
            ]

            color: "#9911111b"
            border.width: 0; radius: 0; focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
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
                anchors.fill: parent; anchors.margins: 14; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Battery"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#ffffff" }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: batRoot.isCharging ? (batRoot.capacity >= 99 ? "Fully Charged" : "󱐋 Charging") : "Discharging"
                        font.family: "Rubik"; font.pixelSize: 12
                        color: "#ffffff"
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#26ffffff" }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Current Charge:"; font.family: "Rubik"; font.pixelSize: 13; color: "#59ffffff" }
                        Item { Layout.fillWidth: true }
                        Text { text: batRoot.capacity + "%"; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#ffffff" }
                    }
                }
            }
        }
    }
}
