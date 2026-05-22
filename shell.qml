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

    // 🎯 LOCAL CENTRAL STATE MACHINE
    property var activeModal: null

    function requestOpen(modalObject) {
        if (activeModal && activeModal !== modalObject) {
            activeModal.visible = false;
        }
        activeModal = modalObject;
        if (activeModal) {
            activeModal.visible = true;
        }
    }

    function dismissAll() {
        if (activeModal) {
            activeModal.visible = false;
            activeModal = null;
        }
    }

    // 🔒 GLOBAL IPC ROUTING MAPS
    IpcHandler {
        target: "launcher"
        function toggle(): void {
            for (let i = 0; i < barWindows.count; i++) {
                let bar = barWindows.objectAt(i);
                if (bar && bar.appLauncherModule) {
                    bar.appLauncherModule.toggleMenu();
                }
            }
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            for (let i = 0; i < barWindows.count; i++) {
                let bar = barWindows.objectAt(i);
                if (bar && bar.wallpaperModule) {
                    bar.wallpaperModule.toggleMenu();
                }
            }
        }
    }

    // 🖥️ MULTI-MONITOR INSTANTIATION TRACKING
    Instantiator {
        id: barWindows
        model: Quickshell.screens

        delegate: PanelWindow {
            id: mainBarWindow
            
            property alias appLauncherModule: appLauncherItem
            property alias wallpaperModule: wallpaperItem

            screen: modelData
            
            anchors.left: true
            anchors.top: true
            anchors.bottom: true
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
                border.color: "#898989"   
                border.width: 1
                radius: 12

                MouseArea {
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.LeftButton
                    onPressed: rootScope.dismissAll()
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: 16
                    anchors.bottomMargin: 16
                    spacing: 0

                    // ==========================================
                    // 👆 TOP UTILITIES BLOCK
                    // ==========================================
                    ColumnLayout {
                        Layout.preferredHeight: 180
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop | Qt.AlignHCenter
                        spacing: 12

                        AppLauncherOsd {
                            id: appLauncherItem
                            Layout.alignment: Qt.AlignHCenter
                        }

                        WallpaperOsd {
                            id: wallpaperItem
                            Layout.alignment: Qt.AlignHCenter
                        }
                        
                        Item { Layout.fillHeight: true }
                    }

                    // ==========================================
                    // 🎯 CENTER WORKSPACES BLOCK
                    // ==========================================
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        
                        Workspaces {
                            anchors.centerIn: parent
                        }
                    }

                    // ==========================================
                    // 👇 BOTTOM STATUS BLOCK
                    // ==========================================
                    ColumnLayout {
                        Layout.preferredHeight: 320
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                        spacing: 12

                        Item { Layout.fillHeight: true }

                        CalendarModule {
                            Layout.alignment: Qt.AlignHCenter
                        }

                        NotificationOsd {
                            Layout.alignment: Qt.AlignHCenter
                        }

                        BluetoothOsd {
                            Layout.alignment: Qt.AlignHCenter
                        }

                        AudioModule {
                            Layout.alignment: Qt.AlignHCenter
                        }

                        PowerOsd {
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
