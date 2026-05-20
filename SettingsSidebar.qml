import QtQuick
import QtQuick.Layouts

Rectangle {
    id: sidebarRoot
    color: "#11111b"
    radius: 16
    layer.enabled: true
    
    property string currentSection: "Notifications"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 6

        Text {
            text: "SETTINGS"
            font.family: "Rubik, sans-serif"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: "#585b70"
            Layout.bottomMargin: 10
        }

        Repeater {
            model: ["Appearance", "Dynamic Island", "Dock", "Music", "OSD", "Notifications", "Control Center", "Advanced"]

            delegate: MouseArea {
                id: btn
                Layout.fillWidth: true
                implicitHeight: 38
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                property bool isSelected: sidebarRoot.currentSection === modelData

                onClicked: sidebarRoot.currentSection = modelData

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: isSelected ? "#313244" : (btn.containsMouse ? "#1e1e2e" : "transparent")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        
                        Text {
                            text: modelData
                            font.family: "Rubik, sans-serif"
                            font.pixelSize: 13
                            font.weight: isSelected ? Font.Medium : Font.Normal
                            color: isSelected ? "#cdd6f4" : "#a6adc8"
                        }
                    }
                }
            }
        }

        // Native QML Layout Spring replacement for Spacer
        Item { 
            Layout.fillHeight: true 
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            color: "#f38ba8"
            radius: 8
            opacity: resetMouse.containsMouse ? 0.9 : 1.0

            Text {
                anchors.centerIn: parent
                text: "RESET DEFAULTS"
                font.family: "Rubik, sans-serif"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: "#11111b"
            }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
            }
        }
    }
}