import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "." 

Scope {
    id: rootScope

    // 🎯 LOCAL CENTRAL STATE MACHINE
    // Tracks the currently active open OSD panel object reference
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

    IpcHandler {
        target: "launcher"
        function toggle(): void { appLauncherModule.toggleMenu(); }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void { wallpaperModule.toggleMenu(); }
    }

    PanelWindow {
        id: mainBarWindow
        
        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 45
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.margins.top: 12
        WlrLayershell.margins.left: 12
        WlrLayershell.margins.right: 12

        Rectangle {
            anchors.fill: parent
            color: "#9911111b"          
            border.color: "#898989"   
            border.width: 1
            radius: 12

            // 🎯 THE BAR DISMISSAL HOOK
            // Catches clicks targeting the empty space or background of the bar.
            // z: -1 ensures it stays behind your interactive module layout row.
            MouseArea {
                anchors.fill: parent
                z: -1
                acceptedButtons: Qt.LeftButton
                onPressed: rootScope.dismissAll()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 0

                // ==========================================
                // 👈 LEFT UTILITIES BLOCK
                // ==========================================
                RowLayout {
                    Layout.preferredWidth: 240
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    spacing: 8

                    AppLauncherOsd {
                        id: appLauncherModule
                        Layout.alignment: Qt.AlignVCenter
                    }

                    WallpaperOsd {
                        id: wallpaperModule
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    Item { Layout.fillWidth: true }
                }

                // ==========================================
                // 🎯 CENTER WORKSPACES BLOCK
                // ==========================================
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    
                    Workspaces {
                        id: workspacesModule
                        anchors.centerIn: parent
                    }
                }

                // ==========================================
                // 👉 RIGHT STATUS BLOCK (Inlined & Reordered)
                // ==========================================
                RowLayout {
                    Layout.preferredWidth: 240
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 6

                    Item { Layout.fillWidth: true }

                    CalendarModule {
                        Layout.alignment: Qt.AlignVCenter
                    }

                    NotificationOsd {
                        Layout.alignment: Qt.AlignVCenter
                    }

                    BluetoothOsd {
                        Layout.alignment: Qt.AlignVCenter
                    }

                    AudioModule {
                        id: audioModule
                        Layout.alignment: Qt.AlignVCenter
                    }

                    PowerOsd {
                        id: powerModule
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
