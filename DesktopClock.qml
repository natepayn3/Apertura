import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Wayland

PanelWindow {
    id: desktopClockWindow

    WlrLayershell.layer: isAlwaysVisible ? WlrLayer.Overlay : WlrLayer.Background
    WlrLayershell.namespace: "desktop-clock-widget"
    
    WlrLayershell.anchors.top: true
    WlrLayershell.anchors.left: true
    WlrLayershell.anchors.bottom: true
    WlrLayershell.anchors.right: true
    
    color: "transparent"

    mask: isAlwaysVisible ? clockInputBounds : null

    Region {
        id: clockInputBounds
        item: clockContentWrapper
    }

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
                font.family: "Rubik"; font.pixelSize: 75; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: Qt.formatDateTime(desktopClockWindow.currentDateTime, "dddd, MMMM d")
                font.family: "Rubik"; font.pixelSize: 24; font.weight: Font.Normal; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
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

        RowLayout {
            id: toggleContainer
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 12
            spacing: 8
            
            visible: dragArea.containsMouse || btnMouseArea.containsMouse

            Text {
                text: desktopClockWindow.isAlwaysVisible ? "keep" : "keep_off"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 18
                Layout.alignment: Qt.AlignVCenter
                color: desktopClockWindow.isAlwaysVisible 
                    ? (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") 
                    : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
            }

            Rectangle {
                id: toggleTrack
                width: 50
                height: 24
                radius: 12
                Layout.alignment: Qt.AlignVCenter
                color: desktopClockWindow.isAlwaysVisible 
                    ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") 
                    : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                
                Rectangle {
                    width: 18
                    height: 18
                    radius: 9
                    color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
                    anchors.verticalCenter: parent.verticalCenter
                    x: desktopClockWindow.isAlwaysVisible ? 28 : 4
                    
                    Behavior on x { 
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad } 
                    }
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
}
