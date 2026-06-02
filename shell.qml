import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Scope {
    id: rootScope

    property alias theme: theme 

    Theme { id: theme }

    property var activeModal: null
    property bool audioSliderActive: false
    property var instantiatedBars: ({})
    property bool sessionLocked: false

    function requestOpen(modalName) { activeModal = modalName; }
    function dismissAll() { activeModal = null; }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].appLauncherModule)
                    rootScope.instantiatedBars[s].appLauncherModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].wallpaperModule)
                    rootScope.instantiatedBars[s].wallpaperModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "notes"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].notesModule)
                    rootScope.instantiatedBars[s].notesModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "sysmonitor"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].sysMonitorModule)
                    rootScope.instantiatedBars[s].sysMonitorModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "netmonitor"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].netMonitorModule)
                    rootScope.instantiatedBars[s].netMonitorModule.toggleMenu();
        }
    }

    Instantiator {
        id: barWindows
        model: Quickshell.screens

        delegate: Scope {
            VolumeHud { targetScreen: modelData }

            PanelWindow {
                id: mainBarWindow
                property string screenKey: modelData.name

                Component.onCompleted: { rootScope.instantiatedBars[screenKey] = mainBarWindow; }
                Component.onDestruction: { delete rootScope.instantiatedBars[screenKey]; }

                property alias appLauncherModule: appLauncherItem
                property alias wallpaperModule: wallpaperItem
                property alias calendarModule: calendarItem
                property alias notesModule: notesItem
                property alias sysMonitorModule: sysMonitorItem
                property alias netMonitorModule: netMonitorItem

                screen: modelData
                anchors { left: true; top: true; bottom: true }
                implicitWidth: 54
                color: "transparent"

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-bar"
                WlrLayershell.margins.top: 12; WlrLayershell.margins.bottom: 12; WlrLayershell.margins.left: 12; WlrLayershell.margins.right: 0

                Rectangle {
                    anchors.fill: parent
                    color: "#9911111b"

                    MouseArea { 
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        onPressed: rootScope.dismissAll() 
                    }

                    Column {
                        id: topStackColumn
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.topMargin: 16
                        spacing: 12

                        AppLauncher { id: appLauncherItem; anchors.horizontalCenter: parent.horizontalCenter }
                        Wallpaper { id: wallpaperItem; anchors.horizontalCenter: parent.horizontalCenter }
                        Calendar { id: calendarItem; anchors.horizontalCenter: parent.horizontalCenter }
                        Item { height: 8; width: 1 }
                        Workspaces { 
                            theme: rootScope.theme 
                            anchors.horizontalCenter: parent.horizontalCenter; z: 1 
                        }
                    }

                    ColumnLayout {
                        id: bottomGroupControls
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 16
                        spacing: 12
                        property bool isExpanded: false

                        Rectangle {
                            id: toggleButton
                            Layout.preferredWidth: 32; Layout.preferredHeight: 32; Layout.alignment: Qt.AlignHCenter
                            color: toggleMouseArea.containsMouse ? "#26ffffff" : "transparent"; radius: 4

                            Text {
                                anchors.centerIn: parent
                                text: bottomGroupControls.isExpanded ? "arrow_drop_down" : "arrow_drop_up"
                                font.family: "Material Symbols Outlined"; font.pixelSize: 30; color: "#ffffff"
                            }

                            MouseArea {
                                id: toggleMouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: bottomGroupControls.isExpanded = !bottomGroupControls.isExpanded
                            }
                        }

                        Item {
                            id: drawerClipWrapper
                            Layout.fillWidth: true
                            implicitHeight: bottomGroupControls.isExpanded ? modulesSubColumn.implicitHeight : 0
                            opacity: bottomGroupControls.isExpanded ? 1.0 : 0.0
                            clip: true

                            Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                            ColumnLayout {
                                id: modulesSubColumn
                                anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; spacing: 12

                                Wifi { Layout.alignment: Qt.AlignHCenter }
                                Battery { Layout.alignment: Qt.AlignHCenter }
                                Notes { id: notesItem; Layout.alignment: Qt.AlignHCenter }
                                Notification { Layout.alignment: Qt.AlignHCenter }
                                Bluetooth { Layout.alignment: Qt.AlignHCenter }
                                Audio { Layout.alignment: Qt.AlignHCenter }
                                SysMonitor { id: sysMonitorItem; theme: rootScope.theme; Layout.alignment: Qt.AlignHCenter }
                                NetMonitor { id: netMonitorItem; Layout.alignment: Qt.AlignHCenter }
                                Power { Layout.alignment: Qt.AlignHCenter }
                            }
                        }
                    }
                }
            }
        }
    }
}
