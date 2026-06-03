import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

Item {
    id: calendarRoot

    implicitWidth: clockHitbox.width
    implicitHeight: clockHitbox.height

    property bool menuOpen: false
    property date currentDateTime: new Date()
    
    readonly property date baseDate: new Date()
    property int currentMonthOffsetIndex: 50
    property date viewerTargetDate: new Date()

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: calendarRoot.currentDateTime = new Date()
    }

    Timer {
        id: osdAutohideTimer; interval: Config.autohideInterval; running: false; repeat: false
        onTriggered: closeMenu()
    }

    function checkUserActivity() {
        if (cardMouseArea.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (drawerTemplate.isOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    function toggleMenu(): void {
        drawerTemplate.isOpen = !drawerTemplate.isOpen;
    }

    function closeMenu(): void {
        drawerTemplate.isOpen = false;
    }

    function updateViewerDate() {
        let monthOffset = calendarRoot.currentMonthOffsetIndex - 50;
        calendarRoot.viewerTargetDate = new Date(calendarRoot.baseDate.getFullYear(), calendarRoot.baseDate.getMonth() + monthOffset, 1);
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: clockHitbox
        width: 44; height: verticalLayout.implicitHeight + 4
        color: clockMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
        radius: 6

        ColumnLayout {
            id: verticalLayout; anchors.centerIn: parent; spacing: 0
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "ddd"); font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"; Layout.alignment: Qt.AlignHCenter }
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "h:mm ap").replace(/\s*[aApP][mM]\s*/g, ""); font.family: "Rubik"; font.pixelSize: 14; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"; Layout.alignment: Qt.AlignHCenter }
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "ap"); font.family: "Rubik"; font.pixelSize: 10; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"; Layout.alignment: Qt.AlignHCenter }
        }

        MouseArea { id: clockMouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: toggleMenu() }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 300
        modalToken: "calendar"
        anchorTop: true

        onIsOpenChanged: {
            if (isOpen) {
                calendarRoot.menuOpen = true;
                calendarRoot.currentMonthOffsetIndex = 50;
                updateViewerDate();
                checkUserActivity();
                mainContainerLayout.forceActiveFocus();
            } else {
                calendarRoot.menuOpen = false;
            }
        }

        MouseArea {
            id: cardMouseArea; anchors.fill: parent; hoverEnabled: true; propagateComposedEvents: true
            onContainsMouseChanged: checkUserActivity()
        }

        MouseArea { anchors.fill: parent; onPressed: (mouse) => { closeMenu(); mouse.accepted = true; } }

        ColumnLayout {
            id: mainContainerLayout
            anchors.fill: parent; anchors.topMargin: 14; anchors.bottomMargin: 14; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
            focus: true

            RowLayout {
                Layout.fillWidth: true; spacing: 0
                Rectangle {
                    width: 28; height: 28; color: prevMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"; radius: 6
                    Text { anchors.centerIn: parent; text: "chevron_left"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                    MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (calendarRoot.currentMonthOffsetIndex > 0) { calendarRoot.currentMonthOffsetIndex--; calendarRoot.updateViewerDate(); } } }
                }
                Item { Layout.fillWidth: true }
                Text { text: Qt.formatDateTime(calendarRoot.viewerTargetDate, "MMMM yyyy"); font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 28; height: 28; color: nextMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"; radius: 6
                    Text { anchors.centerIn: parent; text: "chevron_right"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
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
                                Rectangle { anchors.fill: parent; anchors.margins: 2; color: "transparent"; border.width: parent.isToday ? 2 : 0; border.color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff"; radius: 6 }
                                Text { anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: model.month === grid.month ? 1.0 : 0.25; text: model.day; color: rootScope.theme ? (parent.isToday ? rootScope.theme.theme_primary : rootScope.theme.theme_fg) : "#ffffff"; font.family: grid.font.family; font.pixelSize: grid.font.pixelSize; font.weight: parent.isToday ? Font.Bold : Font.Normal }
                            }
                        }
                    }
                }
            }
        }
    }
}
