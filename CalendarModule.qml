import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Item {
    id: calendarRoot

    implicitWidth: clockHitbox.width
    implicitHeight: clockHitbox.height

    // Controls actual PanelWindow visibility
    property bool menuOpen: false

    // Single source of truth for time updates. Standard property hooks force engine repaints.
    property date currentDateTime: new Date()
    
    // Captured once on file initialization to serve as the baseline virtual index offset point (index 50)
    readonly property date baseDate: new Date()
    
    // Tracking index offset (50 is current month, 49 is previous, 51 is next, etc.)
    property int currentMonthOffsetIndex: 50
    
    // Dynamically tracking evaluation property driven by active list scroll positions
    property date viewerTargetDate: new Date()

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

    // 🎬 ANIMATION-DRIVEN ENGAGEMENT TIMELINE
    function openMenu(): void {
        slideOutAnimation.stop();

        // Compress container completely offscreen relative to screen margin alignments
        popupTranslate.x = -popupCalendarWrapper.width;
        popupCalendarWrapper.opacity = 0.0;

        rootScope.requestOpen(globalCalendarModal);
        menuOpen = true;

        // 🎯 Reset stack offset index instantly back to current month upon open
        calendarRoot.currentMonthOffsetIndex = 50;
        updateViewerDate();

        slideInAnimation.start();
        checkUserActivity();
    }

    function closeMenu(): void {
        slideInAnimation.stop();
        slideOutAnimation.start();
    }

    function updateViewerDate() {
        let monthOffset = calendarRoot.currentMonthOffsetIndex - 50;
        calendarRoot.viewerTargetDate = new Date(calendarRoot.baseDate.getFullYear(), calendarRoot.baseDate.getMonth() + monthOffset, 1);
    }

    // 🔒 STATE LOCK HANDOFF: Listens to the global state register inside shell.qml to cleanly hide the dropdown
    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== globalCalendarModal && menuOpen) {
                closeMenu();
            }
        }
    }

    // ==========================================
    // 🕒 CLOCK TRIGGER MODULE (FIXED VERTICAL)
    // ==========================================
    Rectangle {
        id: clockHitbox
        width: 50
        height: verticalLayout.implicitHeight + 12
        color: clockMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        ColumnLayout {
            id: verticalLayout
            anchors.centerIn: parent
            spacing: 1
            
            Text {
                text: Qt.formatDateTime(calendarRoot.currentDateTime, "ddd")
                font.family: "Rubik"; font.pixelSize: 14; font.weight: Font.Bold; color: "#a6adc8"
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: Qt.formatDateTime(calendarRoot.currentDateTime, "h:mm ap").replace(/\s*[aApP][mM]\s*/g, "")
                font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#cdd6f4"
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: Qt.formatDateTime(calendarRoot.currentDateTime, "ap")
                font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: "#f5c2e7"
                Layout.alignment: Qt.AlignHCenter
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
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"

        WlrLayershell.margins.left: -1; WlrLayershell.margins.right: 1; WlrLayershell.margins.bottom: 0; WlrLayershell.margins.top: 0

        onVisibleChanged: {
            if (visible && calendarRoot.menuOpen) {
                popupCalendarWrapper.forceActiveFocus();
            }
        }

        MouseArea { 
            anchors.fill: parent
            onPressed: (mouse) => {
                closeMenu();
                mouse.accepted = true;
            }
        }

        Rectangle {
            id: popupCalendarWrapper
            width: 300; height: 300 
            anchors.bottom: parent.bottom; anchors.bottomMargin: 12; anchors.left: parent.left; anchors.leftMargin: 1

            transform: Translate { id: popupTranslate; x: -popupCalendarWrapper.width }

            ParallelAnimation {
                id: slideInAnimation
                NumberAnimation { target: popupTranslate; property: "x"; to: 0; duration: 250; easing.type: Easing.OutCubic }
                NumberAnimation { target: popupCalendarWrapper; property: "opacity"; to: 1.0; duration: 180; easing.type: Easing.OutQuad }
            }

            ParallelAnimation {
                id: slideOutAnimation
                onFinished: calendarRoot.menuOpen = false
                NumberAnimation { target: popupTranslate; property: "x"; to: -popupCalendarWrapper.width; duration: 220; easing.type: Easing.InCubic }
                NumberAnimation { target: popupCalendarWrapper; property: "opacity"; to: 0.0; duration: 160; easing.type: Easing.OutQuad }
            }

            color: "#9911111b"; border.width: 0; focus: true
            topLeftRadius: 0; bottomLeftRadius: 0; topRightRadius: 0; bottomRightRadius: 0

            Keys.onPressed: (event) => { if (event.key === Qt.Key_Escape) { closeMenu(); event.accepted = true; } }

            MouseArea {
                id: cardMouseArea
                anchors.fill: parent
                hoverEnabled: true
                propagateComposedEvents: true
                onContainsMouseChanged: checkUserActivity()
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 14; anchors.bottomMargin: 14
                    anchors.leftMargin: 12; anchors.rightMargin: 12
                    spacing: 10

                    // RESTORED EDGE-ALIGNED NAVIGATION HEADER
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        // Previous Month Chevron Trigger
                        Rectangle {
                            width: 28; height: 28
                            color: prevMouse.containsMouse ? "#313244" : "transparent"
                            radius: 6

                            Text {
                                anchors.centerIn: parent
                                text: "chevron_left"
                                font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: "#a6adc8"
                            }

                            MouseArea {
                                id: prevMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (calendarRoot.currentMonthOffsetIndex > 0) {
                                        calendarRoot.currentMonthOffsetIndex--;
                                        calendarRoot.updateViewerDate();
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Central Month Label Title block
                        Text {
                            text: Qt.formatDateTime(calendarRoot.viewerTargetDate, "MMMM yyyy")
                            font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#cdd6f4" 
                        }

                        Item { Layout.fillWidth: true }

                        // Next Month Chevron Trigger
                        Rectangle {
                            width: 28; height: 28
                            color: nextMouse.containsMouse ? "#313244" : "transparent"
                            radius: 6

                            Text {
                                anchors.centerIn: parent
                                text: "chevron_right"
                                font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: "#a6adc8"
                            }

                            MouseArea {
                                id: nextMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (calendarRoot.currentMonthOffsetIndex < 100) {
                                        calendarRoot.currentMonthOffsetIndex++;
                                        calendarRoot.updateViewerDate();
                                    }
                                }
                            }
                        }
                    }

                    // 🎯 THE FIX: StackLayout swaps grids instantaneously with zero animation overhead or lag
                    StackLayout {
                        id: calendarDisplayStack
                        Layout.fillWidth: true; Layout.fillHeight: true
                        
                        // Active grid frame points straight to the current relative month array offset tracker
                        currentIndex: calendarRoot.currentMonthOffsetIndex

                        Repeater {
                            model: 101 // Generates a wide window of months to jump through safely
                            
                            delegate: Item {
                                readonly property int currentVirtualOffset: index - 50
                                readonly property int resolvedMonthPosition: calendarRoot.baseDate.getMonth() + currentVirtualOffset
                                readonly property date loopCalculatedDate: new Date(calendarRoot.baseDate.getFullYear(), resolvedMonthPosition, 1)

                                MonthGrid {
                                    id: grid
                                    anchors.fill: parent
                                    month: parent.loopCalculatedDate.getMonth()
                                    year: parent.loopCalculatedDate.getFullYear()
                                    font.family: "Rubik"; font.pixelSize: 12

                                    delegate: Item {
                                        implicitWidth: 32; implicitHeight: 32
                                        
                                        readonly property bool isToday: model.day === calendarRoot.currentDateTime.getDate() 
                                                                        && model.month === calendarRoot.currentDateTime.getMonth()
                                                                        && model.year === calendarRoot.currentDateTime.getFullYear()

                                        Rectangle {
                                            anchors.fill: parent; anchors.margins: 2
                                            color: "transparent"
                                            border.width: parent.isToday ? 2 : 0 
                                            border.color: "#cdd6f4"; radius: 6
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                            opacity: model.month === grid.month ? 1.0 : 0.3
                                            text: model.day; color: "#cdd6f4" 
                                            font.family: grid.font.family; font.pixelSize: grid.font.pixelSize
                                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
