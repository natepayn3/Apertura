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

    // ==========================================
    // 🔋 POWER TRIGGER MODULE
    // ==========================================
    Rectangle {
        id: powerHitbox
        width: 32
        height: 32
        color: powerMouseArea.containsMouse || globalPowerModal.visible ? "#313244" : "transparent"
        radius: 8

        Text {
            id: powerIcon
            text: "⏻"
            font.family: "Rubik"
            font.pixelSize: 16
            color: globalPowerModal.visible ? "#f38ba8" : "#a6adc8"
            anchors.centerIn: parent
        }

        MouseArea {
            id: powerMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (globalPowerModal.visible) {
                    rootScope.dismissAll();
                } else {
                    rootScope.requestOpen(globalPowerModal);
                }
            }
        }
    }

    // ==========================================
    // 📅 MODAL WINDOW: Power Overlay
    // ==========================================
    PanelWindow {
        id: globalPowerModal
        visible: false
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrLayershell.OnDemand

        onVisibleChanged: {
            if (visible) {
                popupPowerWrapper.forceActiveFocus();
            }
        }

        MouseArea { 
            anchors.fill: parent; 
            onClicked: rootScope.dismissAll() 
        }

        Process {
            id: sysCmd
            running: false
        }

        function runCommand(args) {
            rootScope.dismissAll();
            sysCmd.command = args;
            sysCmd.running = true;
        }

        Rectangle {
            id: popupPowerWrapper
            width: 160  
            height: menuContentLayout.implicitHeight + 28
            
            anchors.top: parent.top
            anchors.right: parent.right
            
            anchors.topMargin: 5   
            anchors.rightMargin: mainBarWindow.WlrLayershell.margins.right 
            
            color: "#cc11111b" 
            border.color: "#898989" 
            border.width: 1
            radius: 12

            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    rootScope.dismissAll();
                    event.accepted = true;
                }
            }

            Component.onCompleted: popupPowerWrapper.forceActiveFocus()
            MouseArea { anchors.fill: parent; onPressed: (mouse) => mouse.accepted = true }

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