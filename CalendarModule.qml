import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Item {
    id: calendarRoot
    implicitWidth: clockHitbox.width
    implicitHeight: 32

    // ==========================================
    // 🕒 CLOCK TRIGGER MODULE
    // ==========================================
    Rectangle {
        id: clockHitbox
        width: clockLabel.implicitWidth + 16 
        height: 32
        color: clockMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        Text {
            id: clockLabel
            text: Qt.formatDateTime(new Date(), "M/d • h:mm ap")
            font.family: "Rubik"
            font.pixelSize: 14 
            font.weight: Font.Bold
            color: clockMouseArea.containsMouse ? "#afbaff" : "#cdd6f4"
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1 
        }

        MouseArea {
            id: clockMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: globalCalendarModal.visible = !globalCalendarModal.visible
        }

        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: clockLabel.text = Qt.formatDateTime(new Date(), "M/d • h:mm ap")
        }
    }

    // ==========================================
    // 📅 MODAL WINDOW: Calendar Overlay
    // ==========================================
    PanelWindow {
        id: globalCalendarModal
        visible: false
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible) {
                popupCalendarWrapper.forceActiveFocus();
            }
        }

        MouseArea { anchors.fill: parent; onClicked: globalCalendarModal.visible = false }

        Rectangle {
            id: popupCalendarWrapper
            width: 250
            height: 250
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12
            anchors.rightMargin: 40 
            color: "#EE1e1e2e"          
            border.color: "#313244"   
            border.width: 1
            radius: 12

            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    globalCalendarModal.visible = false;
                    event.accepted = true;
                }
            }

            Component.onCompleted: popupCalendarWrapper.forceActiveFocus()
            MouseArea { anchors.fill: parent; onPressed: mouse.accepted = true }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 12; anchors.bottomMargin: 12
                anchors.leftMargin: 8; anchors.rightMargin: 8
                spacing: 12

                Text {
                    text: Qt.formatDateTime(new Date(), "MMMM yyyy")
                    font.family: "Rubik"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#cdd6f4"
                    Layout.alignment: Qt.AlignHCenter
                }

                MonthGrid {
                    id: grid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    month: new Date().getMonth()
                    year: new Date().getFullYear()
                    font.family: "Rubik"; font.pixelSize: 12

                    delegate: Item {
                        implicitWidth: 32; implicitHeight: 32
                        readonly property bool isToday: model.day === new Date().getDate() && model.month === new Date().getMonth()

                        Rectangle {
                            anchors.fill: parent; anchors.margins: 2
                            color: "transparent"
                            border.width: parent.isToday ? 1 : 0
                            border.color: "#f5e0dc"
                            radius: 4
                        }

                        Text {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: model.month === grid.month ? 1.0 : 0.3
                            text: model.day
                            color: parent.isToday ? "#f5e0dc" : "#cdd6f4"
                            font.family: grid.font.family
                            font.pixelSize: grid.font.pixelSize
                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
        }
    }
}