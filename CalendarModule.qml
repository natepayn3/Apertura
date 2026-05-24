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

    // 🎬 ANIMATION-DRIVEN ENGAGEMENT TIMELINE
    function openMenu(): void {
        // Stop any unfinished exit tracking before mapping state changes
        slideOutAnimation.stop();

        // Compress container completely offscreen relative to screen margin alignments
        popupTranslate.x = calendarRoot.isVertical ? -popupCalendarWrapper.width : popupCalendarWrapper.width;
        popupCalendarWrapper.opacity = 0.0;

        rootScope.requestOpen(globalCalendarModal);
        menuOpen = true;

        slideInAnimation.start();
        checkUserActivity();
    }

    function closeMenu(): void {
        slideInAnimation.stop();
        slideOutAnimation.start();
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
        
        // 🌀 BLUR HOOK: Tells Hyprland to target the overlay window for background blur passes
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"

        // Shifts the entire layershell window region 1px to the left
        WlrLayershell.margins.left: -1
        WlrLayershell.margins.right: 1
        WlrLayershell.margins.bottom: 0
        WlrLayershell.margins.top: 0

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
            width: 300  
            height: 300 
            
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12 
            anchors.left: calendarRoot.isVertical ? parent.left : undefined
            anchors.right: calendarRoot.isVertical ? undefined : parent.right
            
            // Adjust wrapper internal margins to compensate for layershell bounds shift
            anchors.leftMargin: calendarRoot.isVertical ? 1 : 0
            anchors.rightMargin: calendarRoot.isVertical ? 0 : -1

            // 🛠️ TRANSFORM LAYER: Handles translation cleanly away from the monitor edge bounds
            transform: Translate {
                id: popupTranslate
                x: calendarRoot.isVertical ? -popupCalendarWrapper.width : popupCalendarWrapper.width
            }

            // ✨ THE EMERGING SLIDE-IN MOTOR
            ParallelAnimation {
                id: slideInAnimation
                NumberAnimation { 
                    target: popupTranslate
                    property: "x"
                    to: 0 
                    duration: 250
                    easing.type: Easing.OutCubic 
                }
                NumberAnimation { 
                    target: popupCalendarWrapper
                    property: "opacity"
                    to: 1.0
                    duration: 180
                    easing.type: Easing.OutQuad 
                }
            }

            // ✨ THE IN-REVERSE RETRACTION MOTOR
            ParallelAnimation {
                id: slideOutAnimation
                
                // Safe Lifecycle Sync: Tells engine to tear down display maps ONLY when geometry is hidden
                onFinished: calendarRoot.menuOpen = false

                NumberAnimation { 
                    target: popupTranslate
                    property: "x"
                    to: calendarRoot.isVertical ? -popupCalendarWrapper.width : popupCalendarWrapper.width
                    duration: 220
                    easing.type: Easing.InCubic 
                }
                NumberAnimation { 
                    target: popupCalendarWrapper
                    property: "opacity"
                    to: 0.0
                    duration: 160
                    easing.type: Easing.OutQuad 
                }
            }

            // 🎨 EXACT COLOR MATCH: Matches `#9911111b` straight from your shell.qml panel configuration
            color: "#9911111b" 
            border.width: 0 
            focus: true
            
            // Native smooth anti-aliased border corner scaling
            antialiasing: true
            
            // 📐 FIXED CLIPPER STYLE: Standard radius values without offscreen texture buffer compounding artifacts
            topLeftRadius: calendarRoot.isVertical ? 0 : 12
            bottomLeftRadius: calendarRoot.isVertical ? 0 : 12
            topRightRadius: calendarRoot.isVertical ? 12 : 0
            bottomRightRadius: calendarRoot.isVertical ? 12 : 0

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            // 🌲 CONTAINER FRAMEWORK: Clips nested elements cleanly matching shape geometry
            Item {
                anchors.fill: parent
                clip: true

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
