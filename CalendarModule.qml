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

    // Controls actual PanelWindow visibility
    property bool menuOpen: false

    // Single source of truth for time updates. Standard property hooks force engine repaints.
    property date currentDateTime: new Date()

    // Global ticking driver updating the centralized root timestamp property register
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: calendarRoot.currentDateTime = new Date()
    }

    // Smart auto-hide countdown tracker
    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    // Helper logic to cleanly handle user presence changes
    function checkUserActivity() {
        if (cardMouseArea.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (menuOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    // 🔓 PUBLIC INTERFACE
    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        // Reset hidden left/right offsets and opacity before mapping (start compressed behind bar)
        popupCalendarWrapper.targetX = calendarRoot.isVertical ? -300 : parent.width + 12;
        popupCalendarWrapper.targetOpacity = 0.0;

        rootScope.requestOpen(globalCalendarModal);
        menuOpen = true;

        // Drive the entry transition timeline sequentially
        slideInAnimation.start();
        checkUserActivity();
    }

    function closeMenu(): void {
        // Slide horizontally backward toward the bar tracking margins on exit
        popupCalendarWrapper.targetX = calendarRoot.isVertical ? -300 : parent.width + 12;
        popupCalendarWrapper.targetOpacity = 0.0;

        closeTimer.start();
    }

    // 🎬 CLOSE FINALIZER TIMELINE TRACKER
    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            calendarRoot.menuOpen = false;
        }
    }

    // 🔒 FIX: Added the missing global lifecycle handoff listener to align with the rest of your bar's state machine
    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== globalCalendarModal && menuOpen) {
                closeMenu();
            }
        }
    }

    // ==========================================
    // 🕒 CLOCK TRIGGER MODULE
    // ==========================================
    Rectangle {
        id: clockHitbox
        width: calendarRoot.isVertical ? 50 : (layoutLoader.item ? layoutLoader.item.implicitWidth + 16 : 0)
        height: calendarRoot.isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight + 12 : 0) : 32
        color: clockMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        Loader {
            id: layoutLoader
            anchors.centerIn: parent
            anchors.verticalCenterOffset: calendarRoot.isVertical ? 0 : 1
            sourceComponent: calendarRoot.isVertical ? verticalLayout : horizontalLayout
        }

        Component {
            id: verticalLayout
            ColumnLayout {
                spacing: 1
                Text {
                    text: Qt.formatDateTime(calendarRoot.currentDateTime, "ddd")
                    font.family: "Rubik"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: "#a6adc8"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: Qt.formatDateTime(calendarRoot.currentDateTime, "h:mm ap").replace(/\s*[aApP][mM]\s*/g, "")
                    font.family: "Rubik"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#cdd6f4"
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: Qt.formatDateTime(calendarRoot.currentDateTime, "ap")
                    font.family: "Rubik"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                    color: "#f5c2e7"
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        Component {
            id: horizontalLayout
            RowLayout {
                Text {
                    text: Qt.formatDateTime(calendarRoot.currentDateTime, "ddd • h:mm ap")
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
            onClicked: toggleMenu()
        }
    }

    // ==========================================
    // 📅 MODAL WINDOW: Calendar Overlay
    // ==========================================
    PanelWindow {
        id: globalCalendarModal
        visible: calendarRoot.menuOpen
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && calendarRoot.menuOpen) {
                popupCalendarWrapper.forceActiveFocus();
            }
        }

        MouseArea { 
            anchors.fill: parent
            onPressed: {
                closeMenu();
                mouse.accepted = true;
            }
        }

        Rectangle {
            id: popupCalendarWrapper
            width: 300  
            height: 300 
            
            // Anchored to the bottom baseline alignment constraint of your floating panel
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            
            // Conditional layout anchors handling horizontal structural breakout splits smoothly
            anchors.left: calendarRoot.isVertical ? parent.left : undefined
            anchors.right: calendarRoot.isVertical ? undefined : parent.right
            
            // Mutable animation target maps bound to the X-axis constraints
            property int targetX: calendarRoot.isVertical ? -300 : 300
            property real targetOpacity: 0.0

            anchors.leftMargin: calendarRoot.isVertical ? targetX : undefined
            anchors.rightMargin: calendarRoot.isVertical ? undefined : targetX
            opacity: targetOpacity

            // ✨ HORIZONTAL SLIDE-RIGHT ENTRY SEQUENCE
            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 } // Holds back just enough for Wayland window map to settle
                ParallelAnimation {
                    NumberAnimation { target: popupCalendarWrapper; property: "targetX"; to: 5; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupCalendarWrapper; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            // ✨ HORIZONTAL EXIT MARGIN TRACKERS
            Behavior on anchors.leftMargin {
                enabled: calendarRoot.isVertical
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on anchors.rightMargin {
                enabled: !calendarRoot.isVertical
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            color: "#cc11111b" 
            border.color: "#898989" 
            border.width: 1
            radius: 12
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 14; anchors.bottomMargin: 14
                anchors.leftMargin: 12; anchors.rightMargin: 12
                spacing: 10

                Text {
                    text: Qt.formatDateTime(calendarRoot.currentDateTime, "MMMM yyyy")
                    font.family: "Rubik"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#cdd6f4" 
                    Layout.alignment: Qt.AlignHCenter
                }

                MonthGrid {
                    id: grid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    month: calendarRoot.currentDateTime.getMonth()
                    year: calendarRoot.currentDateTime.getFullYear()
                    font.family: "Rubik"; font.pixelSize: 12

                    delegate: Item {
                        implicitWidth: 32; implicitHeight: 32
                        readonly property bool isToday: model.day === calendarRoot.currentDateTime.getDate() && model.month === calendarRoot.currentDateTime.getMonth()

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
                    mouse.accepted = true; 
                } 
            }
        }
    }
}
