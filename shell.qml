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

    property var activeModal: null
    property bool audioSliderActive: false
    property var instantiatedBars: ({})
    property bool sessionLocked: false

    function requestOpen(modalName) { activeModal = modalName; }
    function dismissAll() { activeModal = null; }

    IpcHandler {
        target: "session"
        function lock(): void { rootScope.sessionLocked = true; }
    }

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

    Instantiator {
        id: barWindows
        model: Quickshell.screens

        delegate: Scope {

            VolumeHud { targetScreen: modelData }

            PanelWindow {
                id: mainBarWindow

                // Unique identifier string derived from screen data
                property string screenKey: modelData.name

                // Register window instance into reference tracking object
                Component.onCompleted: {
                    rootScope.instantiatedBars[screenKey] = mainBarWindow;
                }

                // Clean up references to prevent leak traces on layout shifts
                Component.onDestruction: {
                    delete rootScope.instantiatedBars[screenKey];
                }

                property alias appLauncherModule: appLauncherItem
                property alias wallpaperModule: wallpaperItem
                property alias calendarModule: calendarItem

                screen: modelData

                anchors {
                    left: true
                    top: true
                    bottom: true
                }

                implicitWidth: 54
                color: "transparent"

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-bar"
                WlrLayershell.margins.top: 12
                WlrLayershell.margins.bottom: 12
                WlrLayershell.margins.left: 12
                WlrLayershell.margins.right: 0

                Rectangle {
                    anchors.fill: parent
                    color: "#9911111b"

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        onPressed: rootScope.dismissAll()
                    }

                    Workspaces {
                        anchors.centerIn: parent
                        z: 1
                    }

                    // =========================
                    // TOP STACK (FULLY CENTER ALIGNED)
                    // =========================
                    Column {
                        id: topStackColumn
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right 
                        anchors.topMargin: 16
                        spacing: 12

                        AppLauncher {
                            id: appLauncherItem
                            anchors.horizontalCenter: parent.horizontalCenter 
                        }

                        Wallpaper {
                            id: wallpaperItem
                            anchors.horizontalCenter: parent.horizontalCenter 
                        }

                        Calendar {
                            id: calendarItem
                            anchors.horizontalCenter: parent.horizontalCenter 
                        }
                    }

                    // Spacer to prevent overlap into bottom region
                    Item {
                        anchors.top: calendarItem.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                    }

                    // =========================
                    // BOTTOM CONTROLS (UNCHANGED)
                    // =========================
                    ColumnLayout {
                        id: bottomGroupControls

                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottomMargin: 16

                        spacing: 12

                        property bool isExpanded: false

                        Rectangle {
                            id: toggleButton
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignHCenter

                            color: toggleMouseArea.containsMouse ? "#26ffffff" : "transparent"
                            radius: 4

                            Text {
                                anchors.centerIn: parent
                                text: bottomGroupControls.isExpanded
                                    ? "expand_circle_down"
                                    : "expand_circle_up"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 22
                                color: "#ffffff"
                            }

                            MouseArea {
                                id: toggleMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bottomGroupControls.isExpanded = !bottomGroupControls.isExpanded
                            }
                        }

                        Item {
                            id: drawerClipWrapper
                            Layout.fillWidth: true

                            implicitHeight: bottomGroupControls.isExpanded
                                ? modulesSubColumn.implicitHeight
                                : 0

                            opacity: bottomGroupControls.isExpanded ? 1.0 : 0.0
                            clip: true

                            Behavior on implicitHeight {
                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                            }

                            ColumnLayout {
                                id: modulesSubColumn
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 12

                                Wifi { Layout.alignment: Qt.AlignHCenter }
                                Battery { Layout.alignment: Qt.AlignHCenter }
                                Notification { Layout.alignment: Qt.AlignHCenter }
                                Bluetooth { Layout.alignment: Qt.AlignHCenter }
                                Audio { Layout.alignment: Qt.AlignHCenter }
                                Power { Layout.alignment: Qt.AlignHCenter }
                            }
                        }
                    }
                }
            }
        }
    }
}
