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
    
    // 🔒 GLOBAL SAFELOCK REGISTER: Tracks when the GUI volume slider is being dragged
    property bool audioSliderActive: false

    // 🗺️ ABSOLUTE INSTANCE TRACKER: Maps explicit panel window pointers by unique hardware names
    property var instantiatedBars: ({})

    // 🔒 LAZY LOCKSCREEN CONTROLLER STATE
    property bool sessionLocked: false

    function requestOpen(modalName) {
        activeModal = modalName;
    }

    function dismissAll() {
        activeModal = null;
    }

    // 🔒 GLOBAL IPC ROUTING MAPS
    IpcHandler {
        target: "session"
        
        function lock(): void {
            rootScope.sessionLocked = true;
        }
    }

    IpcHandler {
        target: "launcher"
        
        function toggle(): void {
            for (let screenName in rootScope.instantiatedBars) {
                let barWindow = rootScope.instantiatedBars[screenName];
                if (barWindow && barWindow.appLauncherModule) {
                    barWindow.appLauncherModule.toggleMenu();
                }
            }
        }
    }

    // 🔄 GLOBAL PANEL HANDOFF SWAP LISTENER
    IpcHandler {
        target: "wallpaper"
        
        function toggle(): void {
            for (let screenName in rootScope.instantiatedBars) {
                let barWindow = rootScope.instantiatedBars[screenName];
                if (barWindow && barWindow.wallpaperModule) {
                    barWindow.wallpaperModule.toggleMenu();
                }
            }
        }
    }

    // 🖥️ MULTI-MONITOR INSTANTIATION TRACKING
    Instantiator {
        id: barWindows
        model: Quickshell.screens

        delegate: Item {
            id: displayGroupContext

            VolumeHudOsd {
                targetScreen: modelData
            }

            PanelWindow {
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

                Component.onCompleted: {
                    if (modelData && modelData.name) {
                        let currentMap = rootScope.instantiatedBars;
                        currentMap[modelData.name] = mainBarWindow;
                        rootScope.instantiatedBars = currentMap;
                    }
                }

                Component.onDestruction: {
                    if (modelData && modelData.name) {
                        let currentMap = rootScope.instantiatedBars;
                        delete currentMap[modelData.name];
                        rootScope.instantiatedBars = currentMap;
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#9911111b"          
                    border.color: "#898989"   
                    border.width: 0
                    radius: 0

                    MouseArea {
                        id: mainBarMouseTracker
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        acceptedButtons: Qt.LeftButton
                        onPressed: rootScope.dismissAll()
                    }

                    Workspaces {
                        anchors.centerIn: parent
                        z: 1 
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 16
                        anchors.bottomMargin: 16
                        spacing: 0

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

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                        }

                        ColumnLayout {
                            Layout.preferredHeight: 320
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                            spacing: 12

                            Item { Layout.fillHeight: true }

                            CalendarModule {
                                Layout.alignment: Qt.AlignHCenter
                            }

                            WifiOsd {
                                Layout.alignment: Qt.AlignHCenter
                            }

                            BatteryOsd {
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
}
