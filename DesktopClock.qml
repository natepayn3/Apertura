import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: desktopClockWindow

    WlrLayershell.layer: isAlwaysVisible ? WlrLayer.Overlay : WlrLayer.Bottom
    WlrLayershell.namespace: "desktop-clock-widget"
    WlrLayershell.anchors.top: true
    WlrLayershell.anchors.left: true
    WlrLayershell.anchors.bottom: true
    WlrLayershell.anchors.right: true
    
    color: "transparent"

    property date currentDateTime: new Date()
    property bool isAlwaysVisible: false 

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: desktopClockWindow.currentDateTime = new Date()
    }

    Rectangle {
        id: clockContentWrapper
        
        property int posX: desktopClockWindow.width - width - 25
        property int posY: 25

        x: posX
        y: posY
        width: 400
        height: 175
        
        color: "#9911111b"
        radius: 0
        border.width: 0

        ColumnLayout {
            id: layoutContainer
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: Qt.formatDateTime(desktopClockWindow.currentDateTime, "h:mm ap")
                font.family: "Rubik"; font.pixelSize: 75; font.weight: Font.Bold; color: "#ffffff"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: Qt.formatDateTime(desktopClockWindow.currentDateTime, "dddd, MMMM d")
                font.family: "Rubik"; font.pixelSize: 24; font.weight: Font.Normal; color: "#ffffff"
                Layout.alignment: Qt.AlignHCenter
            }
        }

        MouseArea {
            id: dragArea
            anchors.fill: parent
            cursorShape: containsMouse ? Qt.SizeAllCursor : Qt.ArrowCursor
            hoverEnabled: true

            property int clickOffsetX: 0
            property int clickOffsetY: 0

            onPressed: (mouse) => {
                clickOffsetX = mouse.x
                clickOffsetY = mouse.y
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    clockContentWrapper.posX = clockContentWrapper.posX + mouse.x - clickOffsetX
                    clockContentWrapper.posY = clockContentWrapper.posY + mouse.y - clickOffsetY
                }
            }
        }

        Rectangle {
            id: toggleButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            width: 110
            height: 26
            radius: 0 
            
            visible: dragArea.containsMouse || btnMouseArea.containsMouse
            
            color: desktopClockWindow.isAlwaysVisible ? "#45ffffff" : "transparent"
            border.width: desktopClockWindow.isAlwaysVisible ? 0 : 1
            border.color: "#26ffffff"

            Text {
                anchors.centerIn: parent
                text: "Always Visible"
                font.family: "Rubik"
                font.pixelSize: 11
                font.weight: Font.Medium
                color: "#ffffff"
            }

            MouseArea {
                id: btnMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true 
                
                onClicked: {
                    desktopClockWindow.isAlwaysVisible = !desktopClockWindow.isAlwaysVisible
                }
            }
        }
    }
}
