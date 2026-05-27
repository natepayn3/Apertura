import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: batRoot
    
    // 🎯 DYNAMIC VISIBILITY CONFIGURATION: Collapses dimensions when on a desktop layout
    property bool isLaptop: false
    
    implicitWidth: isLaptop ? 32 : 0
    implicitHeight: isLaptop ? 32 : 0
    visible: isLaptop

    property int capacity: 100
    property bool isCharging: false
    property bool menuOpen: false

    // ⚡ Hardware Presence Check: Verifies the path exists before enabling bindings
    Process {
        id: presenceCheck
        command: ["test", "-f", "/sys/class/power_supply/BAT1/capacity"]
        running: true
        
        onExited: (code) => {
            if (code === 0) {
                batRoot.isLaptop = true;
                capReader.reload();
                statusReader.reload();
            } else {
                batRoot.isLaptop = false;
            }
        }
    }

    // ⚡ Sysfs tracking nodes (Path collapses safely to empty strings on desktops)
    FileView {
        id: capReader
        path: batRoot.isLaptop ? "/sys/class/power_supply/BAT1/capacity" : ""
        onTextChanged: {
            let cleanText = text().trim();
            if (cleanText.length > 0) {
                batRoot.capacity = parseInt(cleanText) || 100;
            }
        }
    }

    // ⚡ Sysfs status tracker node
    FileView {
        id: statusReader
        path: batRoot.isLaptop ? "/sys/class/power_supply/BAT1/status" : ""
        onTextChanged: {
            batRoot.isCharging = (text().trim() === "Charging");
        }
    }

    // 🕒 Sync hardware nodes every 15 seconds if on a laptop setup
    Timer {
        interval: 15000
        running: batRoot.isLaptop
        repeat: true
        onTriggered: {
            capReader.reload();
            statusReader.reload();
        }
    }

    // 🎬 CLOSE FINALIZER TIMER
    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            batRoot.menuOpen = false;
        }
    }

    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;

        rootScope.requestOpen("battery");
        menuOpen = true;

        slideInAnimation.start();
    }

    function closeMenu(): void {
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;
        closeTimer.start();
    }

    // ==========================================
    // 🔋 BATTERY ICON TRIGGER MODULE
    // ==========================================
    Rectangle {
        id: batteryHitbox
        anchors.fill: parent
        color: batteryMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 0 

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                id: batteryIcon
                Layout.alignment: Qt.AlignHCenter
                
                text: batRoot.isCharging     ? "battery_charging_full" : 
                    batRoot.capacity < 25    ? "battery_android_1" : 
                    batRoot.capacity < 50    ? "battery_android_3" : 
                    batRoot.capacity < 75    ? "battery_android_6" : 
                                               "battery_android_full" 
                                                    
                font.family: "Material Symbols Outlined" 
                font.pixelSize: 20
                color: batRoot.capacity < 25 && !batRoot.isCharging ? "#f38ba8" : "#a6e3a1"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        MouseArea {
            id: batteryMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()

            // 🎯 Fixed Battery Tooltip
            ToolTip {
                id: batTooltip
                visible: parent.containsMouse
                delay: 400
                
                // 🎯 THE FIX: Adds a comfortable padding buffer safely without touching read-only metrics
                leftPadding: 8
                rightPadding: 8
                topPadding: 4
                bottomPadding: 4

                contentItem: Text {
                    text: batRoot.isCharging ? "Charging (" + batRoot.capacity + "%)" : batRoot.capacity + "%"
                    font.family: "Rubik"
                    font.weight: Font.Regular
                    font.pixelSize: 14
                    color: "#cdd6f4"
                    textFormat: Text.PlainText
                    horizontalAlignment: Text.AlignHCenter
                }

                background: Rectangle {
                    color: "#11111b"
                    border.color: "#313244"
                    border.width: 1
                    radius: 4
                }
            }
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

    // ==========================================
    // 🪟 OVERLAY MENU CARD
    // ==========================================
    PanelWindow {
        id: batteryOverlayModal
        visible: batRoot.menuOpen
        color: "transparent"
        
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        
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
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.bottomMargin: 12
            property int targetX: -655; property real targetOpacity: 0.0
            anchors.leftMargin: targetX; opacity: targetOpacity

            SequentialAnimation {
                id: slideInAnimation; PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupMenuFrame; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupMenuFrame; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }
            
            Behavior on anchors.leftMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

            color: "#9911111b"; border.width: 0; radius: 0; focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            MouseArea { 
                anchors.fill: parent
                onPressed: (mouse) => { mouse.accepted = true; } 
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Battery"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#cdd6f4" }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: batRoot.isCharging ? "󱐋 Charging" : "Discharging"
                        font.family: "Rubik"; font.pixelSize: 12
                        color: batRoot.isCharging ? "#a6e3a1" : "#a6adc8"
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Current Charge:"; font.family: "Rubik"; font.pixelSize: 13; color: "#a6adc8" }
                        Item { Layout.fillWidth: true }
                        Text { text: batRoot.capacity + "%"; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#cdd6f4" }
                    }
                }
            }
        }
    }
}
