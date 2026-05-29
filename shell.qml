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

    IpcHandler { target: "session"; function lock(): void { rootScope.sessionLocked = true; } }
    IpcHandler { target: "launcher"; function toggle(): void { for (let s in rootScope.instantiatedBars) if (rootScope.instantiatedBars[s].appLauncherModule) rootScope.instantiatedBars[s].appLauncherModule.toggleMenu(); } }
    IpcHandler { target: "wallpaper"; function toggle(): void { for (let s in rootScope.instantiatedBars) if (rootScope.instantiatedBars[s].wallpaperModule) rootScope.instantiatedBars[s].wallpaperModule.toggleMenu(); } }

    Instantiator {
        id: barWindows
        model: Quickshell.screens
        
        delegate: Scope {
            WorkspacePreview {
                id: workspacePreviewWindow
                targetScreen: modelData
            }
            
            VolumeHud { targetScreen: modelData }
            
            PanelWindow {
                id: mainBarWindow
                property alias appLauncherModule: appLauncherItem
                property alias wallpaperModule: wallpaperItem
                property alias previewHandle: workspacePreviewWindow
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
                    MouseArea { anchors.fill: parent; hoverEnabled: true; z: -1; onPressed: rootScope.dismissAll() }
                    Workspaces { anchors.centerIn: parent; z: 1 }
                    ColumnLayout {
                        anchors.fill: parent; anchors.topMargin: 16; anchors.bottomMargin: 16; spacing: 0
                        ColumnLayout {
                            Layout.preferredHeight: 180; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop | Qt.AlignHCenter; spacing: 12
                            AppLauncher { id: appLauncherItem; Layout.alignment: Qt.AlignHCenter }
                            Wallpaper { id: wallpaperItem; Layout.alignment: Qt.AlignHCenter }
                            Item { Layout.fillHeight: true }
                        }
                        Item { Layout.fillWidth: true; Layout.fillHeight: true }
                        ColumnLayout {
                            id: bottomGroupControls
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter; spacing: 12
                            property bool isExpanded: false
                            CalendarModule { Layout.alignment: Qt.AlignHCenter }
                            Rectangle {
                                id: toggleButton; Layout.preferredWidth: 32; Layout.preferredHeight: 32; Layout.alignment: Qt.AlignHCenter
                                color: toggleMouseArea.containsMouse ? "#26ffffff" : "transparent"; radius: 4
                                Text { anchors.centerIn: parent; text: bottomGroupControls.isExpanded ? "expand_circle_down" : "expand_circle_up"; font.family: "Material Symbols Outlined"; font.pixelSize: 22; color: "#ffffff" }
                                MouseArea { id: toggleMouseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bottomGroupControls.isExpanded = !bottomGroupControls.isExpanded }
                            }
                            Item {
                                id: drawerClipWrapper; Layout.fillWidth: true; implicitHeight: bottomGroupControls.isExpanded ? modulesSubColumn.implicitHeight : 0; opacity: bottomGroupControls.isExpanded ? 1.0 : 0.0; clip: true
                                Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                                ColumnLayout {
                                    id: modulesSubColumn; anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter; spacing: 12 
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
}
