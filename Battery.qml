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
            if (typeof text === "function" && text()) {
                let cleanText = text().trim();
                if (cleanText.length > 0) {
                    batRoot.capacity = parseInt(cleanText) || 100;
                }
            }
        }
    }

    // ⚡ Sysfs status tracker node
    FileView {
        id: statusReader
        path: batRoot.isLaptop ? "/sys/class/power_supply/BAT1/status" : ""
        onTextChanged: {
            if (typeof text === "function" && text()) {
                batRoot.isCharging = (text().trim() === "Charging");
            }
        }
    }

    // 🕒 Sync hardware nodes every 15 seconds if on a laptop setup
    Timer {
        interval: 1000
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
        // Unified monochrome hover mask
        color: batteryMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 0 

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                id: batteryIcon
                Layout.alignment: Qt.AlignHCenter
                
                // 📊 Check mouse hover first: if true, show percentage string; if false, show the android glyphs
                text: batteryMouseArea.containsMouse ? batRoot.capacity + "%" : (
                    batRoot.isCharging       ? "battery_android_frame_bolt" : 
                    batRoot.capacity < 10    ? "battery_android_0" :
                    batRoot.capacity < 20    ? "battery_android_1" : 
                    batRoot.capacity < 30    ? "battery_android_2" : 
                    batRoot.capacity < 40    ? "battery_android_3" : 
                    batRoot.capacity < 50    ? "battery_android_4" : 
                    batRoot.capacity < 60    ? "battery_android_5" : 
                    batRoot.capacity < 70    ? "battery_android_6" : 
                    batRoot.capacity < 80    ? "battery_android_7" : 
                    batRoot.capacity < 90    ? "battery_android_8" : 
                    batRoot.capacity < 98    ? "battery_android_9" : 
                                            "battery_android_full"
                )
                                                    
                // Dynamic styling layout to handle the transition between the icon font and regular text digits cleanly
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
        
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        
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

            // Dynamic blur-through window base
            color: "#9911111b"
            border.width: 0; radius: 0; focus: true
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
                    Text { text: "Battery"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#ffffff" }
                    Item { Layout.fillWidth: true }
                    Text { 
                        text: batRoot.isCharging ? "󱐋 Charging" : "Discharging"
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
