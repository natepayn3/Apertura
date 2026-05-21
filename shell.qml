import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "." 

Scope {
    id: rootScope

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

            // 🎯 FIXED: Direct, top-level RowLayout anchors everything uniformly
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
                    
                    // Spacer pushing items left
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
                // 👉 RIGHT STATUS BLOCK
                // ==========================================
                RowLayout {
                    Layout.preferredWidth: 240
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    spacing: 6

                    // Spacer pushing items right
                    Item { Layout.fillWidth: true }

                    RightStatus {
                        id: rightStatusModule
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
