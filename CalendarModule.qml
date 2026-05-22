import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Item {
    id: calendarRoot
    
    // 🎛️ ORIENTATION TOGGLE
    property bool isVertical: true

    implicitWidth: clockHitbox.width
    implicitHeight: clockHitbox.height

    // Smart auto-hide countdown tracker
    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: rootScope.dismissAll()
    }

    // Helper logic to cleanly handle user presence changes
    function checkUserActivity() {
        if (cardMouseArea.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (globalCalendarModal.visible) {
            osdAutohideTimer.restart(); 
        }
    }

    // ==========================================
    // 🕒 CLOCK TRIGGER MODULE
    // ==========================================
    Rectangle {
        id: clockHitbox
        // 🔒 FIXED: Apply null guards to prevent 'implicitWidth' reads from crashing if item context is null
        width: calendarRoot.isVertical ? 50 : (layoutLoader.item ? layoutLoader.item.implicitWidth + 16 : 0)
        height: calendarRoot.isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight + 12 : 0) : 32
        color: clockMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        // Handles the structural switch between RowLayout and ColumnLayout based on bar orientation
        Loader {
            id: layoutLoader
            anchors.centerIn: parent
            anchors.verticalCenterOffset: calendarRoot.isVertical ? 0 : 1
            sourceComponent: calendarRoot.isVertical ? verticalLayout : horizontalLayout
        }

        // 🔄 VERTICAL AXIS STACKING (Day name on top of 12h h:mm, with am/pm at the bottom)
        Component {
            id: verticalLayout
            ColumnLayout {
                spacing: 1
                Text {
                    text: Qt.formatDateTime(new Date(), "ddd")
                    font.family: "Rubik"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#a6adc8"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: Qt.formatDateTime(new Date(), "h:mm ap").replace(/\s*[aApP][mM]\s*/g, "")
                    font.family: "Rubik"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#cdd6f4"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: Qt.formatDateTime(new Date(), "ap")
                    font.family: "Rubik"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: "#f5c2e7"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // ↔️ HORIZONTAL AXIS STACKING (Updated baseline format string)
        Component {
            id: horizontalLayout
            RowLayout {
                Text {
                    text: Qt.formatDateTime(new Date(), "ddd • h:mm ap")
                    font.family: "Rubik"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#cdd6f4"
                }
            }
        }

        MouseArea {
            id: clockMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (globalCalendarModal.visible) {
                    rootScope.dismissAll();
                } else {
                    rootScope.requestOpen(globalCalendarModal);
                    checkUserActivity();
                }
            }
        }

        // Global ticking driver updates the dynamic layout state definitions
        Timer {
            interval: 1000
            running: true
            repeat: true
            onTriggered: {
                var d = new Date();
                if (layoutLoader.item) {
                    layoutLoader.activeFocusItem; 
                }
            }
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

        MouseArea { 
            anchors.fill: parent; 
            onClicked: rootScope.dismissAll() 
        }

        Rectangle {
            id: popupCalendarWrapper
            width: 300  
            height: 300 
            
            anchors.bottom: calendarRoot.isVertical ? parent.bottom : undefined
            anchors.top: calendarRoot.isVertical ? undefined : parent.top
            anchors.left: calendarRoot.isVertical ? parent.left : undefined
            anchors.right: calendarRoot.isVertical ? undefined : parent.right
            
            anchors.leftMargin: calendarRoot.isVertical ? 5 : 0
            anchors.rightMargin: calendarRoot.isVertical ? 0 : 12 
            anchors.topMargin: calendarRoot.isVertical ? 0 : 5
            anchors.bottomMargin: calendarRoot.isVertical ? (globalCalendarModal.visible ? 12 : -48) : 0

            color: "#cc11111b" 
            border.color: "#898989" 
            border.width: 1
            radius: 12
            focus: true

            opacity: globalCalendarModal.visible ? 1.0 : 0.0

            Behavior on anchors.bottomMargin {
                id: slideAnimation
                enabled: calendarRoot.isVertical
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    rootScope.dismissAll();
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
