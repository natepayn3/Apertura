import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Item {
    id: calendarRoot

    implicitWidth: clockHitbox.width
    implicitHeight: clockHitbox.height

    property bool menuOpen: false
    property date currentDateTime: new Date()
    
    readonly property date baseDate: new Date()
    property int currentMonthOffsetIndex: 50
    property date viewerTargetDate: new Date()
    property bool windowAlive: false

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: calendarRoot.currentDateTime = new Date()
    }

    Timer {
        id: osdAutohideTimer; interval: 3500; running: false; repeat: false
        onTriggered: closeMenu()
    }

    function checkUserActivity() {
        if (cardMouseArea.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (menuOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    function toggleMenu(): void { if (menuOpen) { closeMenu(); } else { openMenu(); } }

    function openMenu(): void {
        rootScope.requestOpen(globalCalendarModal);
        windowAlive = true;
        menuOpen = true;
        calendarRoot.currentMonthOffsetIndex = 50;
        updateViewerDate();
        checkUserActivity();
    }

    function closeMenu(): void { menuOpen = false; }
    function updateViewerDate() {
        let monthOffset = calendarRoot.currentMonthOffsetIndex - 50;
        calendarRoot.viewerTargetDate = new Date(calendarRoot.baseDate.getFullYear(), calendarRoot.baseDate.getMonth() + monthOffset, 1);
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() { if (rootScope.activeModal !== globalCalendarModal && menuOpen) { closeMenu(); } }
    }

    Rectangle {
        id: clockHitbox
        width: 44; height: verticalLayout.implicitHeight + 4
        color: clockMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 6

        ColumnLayout {
            id: verticalLayout; anchors.centerIn: parent; spacing: 0
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "ddd"); font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: "#59ffffff"; Layout.alignment: Qt.AlignHCenter }
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "h:mm ap").replace(/\s*[aApP][mM]\s*/g, ""); font.family: "Rubik"; font.pixelSize: 14; font.weight: Font.Bold; color: "#ffffff"; Layout.alignment: Qt.AlignHCenter }
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "ap"); font.family: "Rubik"; font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff"; Layout.alignment: Qt.AlignHCenter }
        }

        MouseArea { id: clockMouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: toggleMenu() }
    }

    PanelWindow {
        id: globalCalendarModal; visible: calendarRoot.windowAlive
        WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "quickshell-overlay"; WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; color: "transparent"
        WlrLayershell.margins.left: -1; WlrLayershell.margins.right: 1; WlrLayershell.margins.bottom: 0; WlrLayershell.margins.top: 0

        onVisibleChanged: { if (visible && calendarRoot.menuOpen) { popupCalendarWrapper.forceActiveFocus(); } }
        MouseArea { anchors.fill: parent; onPressed: (mouse) => { closeMenu(); mouse.accepted = true; } }

        Rectangle {
            id: popupCalendarWrapper; width: 300; height: 300 
            
            y: 12
            
            states: [
                State {
                    name: "visible"
                    when: calendarRoot.menuOpen
                    PropertyChanges { target: popupCalendarWrapper; x: 1; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: !calendarRoot.menuOpen
                    PropertyChanges { target: popupCalendarWrapper; x: -320; opacity: 0.0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "visible"
                    ParallelAnimation {
                        NumberAnimation { property: "x"; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.OutCubic }
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { property: "x"; duration: 350; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.InCubic }
                        }
                        ScriptAction {
                            script: { calendarRoot.windowAlive = false; }
                        }
                    }
                }
            ]

            color: "#9911111b"; border.width: 0; focus: true
            topLeftRadius: 0; bottomLeftRadius: 0; topRightRadius: 0; bottomRightRadius: 0
            Keys.onPressed: (event) => { if (event.key === Qt.Key_Escape) { closeMenu(); event.accepted = true; } }

            MouseArea {
                id: cardMouseArea; anchors.fill: parent; hoverEnabled: true; propagateComposedEvents: true
                onContainsMouseChanged: checkUserActivity()
                
                ColumnLayout {
                    anchors.fill: parent; anchors.topMargin: 14; anchors.bottomMargin: 14; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10

                    RowLayout {
                        Layout.fillWidth: true; spacing: 0
                        Rectangle {
                            width: 28; height: 28; color: prevMouse.containsMouse ? "#26ffffff" : "transparent"; radius: 6
                            Text { anchors.centerIn: parent; text: "chevron_left"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: "#ffffff" }
                            MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (calendarRoot.currentMonthOffsetIndex > 0) { calendarRoot.currentMonthOffsetIndex--; calendarRoot.updateViewerDate(); } } }
                        }
                        Item { Layout.fillWidth: true }
                        Text { text: Qt.formatDateTime(calendarRoot.viewerTargetDate, "MMMM yyyy"); font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#ffffff" }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 28; height: 28; color: nextMouse.containsMouse ? "#26ffffff" : "transparent"; radius: 6
                            Text { anchors.centerIn: parent; text: "chevron_right"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: "#ffffff" }
                            MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (calendarRoot.currentMonthOffsetIndex < 100) { calendarRoot.currentMonthOffsetIndex++; calendarRoot.updateViewerDate(); } } }
                        }
                    }

                    StackLayout {
                        id: calendarDisplayStack; Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: calendarRoot.currentMonthOffsetIndex
                        Repeater {
                            model: 101
                            delegate: Item {
                                readonly property int currentVirtualOffset: index - 50
                                readonly property int resolvedMonthPosition: calendarRoot.baseDate.getMonth() + currentVirtualOffset
                                readonly property date loopCalculatedDate: new Date(calendarRoot.baseDate.getFullYear(), resolvedMonthPosition, 1)

                                MonthGrid {
                                    id: grid; anchors.fill: parent; month: parent.loopCalculatedDate.getMonth(); year: parent.loopCalculatedDate.getFullYear(); font.family: "Rubik"; font.pixelSize: 12
                                    delegate: Item {
                                        implicitWidth: 32; implicitHeight: 32
                                        readonly property bool isToday: model.day === calendarRoot.currentDateTime.getDate() && model.month === calendarRoot.currentDateTime.getMonth() && model.year === calendarRoot.currentDateTime.getFullYear()
                                        Rectangle { anchors.fill: parent; anchors.margins: 2; color: "transparent"; border.width: parent.isToday ? 2 : 0; border.color: "#ffffff"; radius: 6 }
                                        Text { anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: model.month === grid.month ? 1.0 : 0.25; text: model.day; color: "#ffffff"; font.family: grid.font.family; font.pixelSize: grid.font.pixelSize; font.weight: parent.isToday ? Font.Bold : Font.Normal }
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
