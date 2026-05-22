import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Item {
    id: calendarRoot
    implicitWidth: clockHitbox.width
    implicitHeight: 32

    // Smart auto-hide countdown tracker
    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: globalCalendarModal.visible = false
    }

    // Helper logic to cleanly handle user presence changes
    function checkUserActivity() {
        if (cardMouseArea.containsMouse) {
            osdAutohideTimer.stop(); // Interacting: Freeze dismissal rule
        } else if (globalCalendarModal.visible) {
            osdAutohideTimer.restart(); // Left environment bounds: Start countdown ticking
        }
    }

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
            font.pixelSize: 16
            font.weight: Font.Bold
            color: "#cdd6f4" // 🔒 FIXED: Color stays locked to default text tone on hover
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 1 
        }

        MouseArea {
            id: clockMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                globalCalendarModal.visible = !globalCalendarModal.visible;
                if (globalCalendarModal.visible) {
                    checkUserActivity();
                }
            }
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
        WlrLayershell.keyboardFocus: WlrLayershell.OnDemand

        onVisibleChanged: {
            if (visible) {
                popupCalendarWrapper.forceActiveFocus();
            }
        }

        // Listen to the attached window property to handle focus dropouts safely
        Connections {
            target: Quickshell.window
            function onActiveChanged() {
                if (!Quickshell.window.active && globalCalendarModal.visible) {
                    globalCalendarModal.visible = false;
                }
            }
        }

        MouseArea { 
            anchors.fill: parent; 
            onClicked: globalCalendarModal.visible = false 
        }

        Rectangle {
            id: popupCalendarWrapper
            width: 300  
            height: 300 
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 5   
            anchors.rightMargin: 12 
            color: "#cc11111b" // 🎯 MATCHED: Swapped to 80% opacity glass profile to match launcher/wallpaper
            border.color: "#898989" 
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

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 14; anchors.bottomMargin: 14
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: Qt.formatDateTime(new Date(), "MMMM yyyy")
                    font.family: "Rubik"
                    font.pixelSize: 16
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
                            border.width: parent.isToday ? 2 : 0 
                            border.color: "#cdd6f4" 
                            radius: 6
                        }

                        Text {
                            anchors.centerIn: parent
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            opacity: model.month === grid.month ? 1.0 : 0.3
                            text: model.day
                            color: "#cdd6f4" 
                            font.family: grid.font.family
                            font.pixelSize: grid.font.pixelSize
                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                        }
                    }
                }
            }

            // Raised overlay tracker intercepts focus transparently to avoid grid component masking
            MouseArea { 
                id: cardMouseArea
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true 
                
                onContainsMouseChanged: checkUserActivity()
                onPressed: (mouse) => { 
                    checkUserActivity();
                    mouse.accepted = false; 
                } 
            }
        }
    }
}