import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: wallpaperModuleRoot
    implicitWidth: 32
    implicitHeight: 32

    property string wallpaperDir: "/home/nick/Pictures/Wallpapers"
    property var wallpapers: []

    ListModel {
        id: wallpaperModel
    }

    // 🔓 PUBLIC INTERFACE: Allows internal or external IPC toggles
    function toggleMenu() {
        // 🎯 Hooked into the central state machine
        if (wallpaperModal.visible) {
            rootScope.dismissAll();
        } else {
            rootScope.requestOpen(wallpaperModal);
            wallpaperScanner.running = false;
            wallpaperScanner.running = true;
            wallpaperCard.forceActiveFocus();
        }
    }

    function populateWallpapers(rawText) {
        wallpaperModel.clear();
        let lines = rawText.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (line !== "") {
                wallpaperModel.append({
                    fileName: line,
                    fullPath: wallpaperDir + "/" + line
                });
            }
        }
    }

    // 🔄 WALLPAPER SCANNER: Polls the directory for image payloads
    Process {
        id: wallpaperScanner
        running: true
        command: ["ls", wallpaperDir]

        stdout: StdioCollector {
            onTextChanged: {
                populateWallpapers(text);
            }
        }
    }

    // 🔘 TRIGGER BUTTON
    Rectangle {
        id: triggerButton
        anchors.fill: parent
        color: wallpaperMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        Text {
            anchors.centerIn: parent
            text: "󰸉"
            font.family: "Rubik"
            font.pixelSize: 24
            color: "#cdd6f4" 
        }

        MouseArea {
            id: wallpaperMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    // 🪟 WALLPAPER SELECTOR MODAL WINDOW
    PanelWindow {
        id: wallpaperModal
        visible: false
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-wallpapers"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // 🎯 Route click away to central manager
        MouseArea {
            anchors.fill: parent
            onClicked: rootScope.dismissAll()
        }

        Rectangle {
            id: wallpaperCard
            width: 650
            height: 480
            
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 5
            anchors.leftMargin: 12
            
            color: "#cc11111b" 
            border.color: "#898989" 
            border.width: 1
            radius: 12

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    // 🎯 Route escape to clear globally
                    rootScope.dismissAll();
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                spacing: 12

                Text {
                    text: "Select Wallpaper"
                    font.family: "Rubik"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#cdd6f4" // 🔒 FIXED: Upgraded from #a6adc8 to mirror bright Calendar text specs
                    Layout.leftMargin: 2 
                }

                // 📜 SCROLLABLE VIEW PORT
                Flickable {
                    id: scrollContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: flowGrid.childrenRect.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // 🖼️ RESPONSIVE WRAPPING GRID CONTAINER
                    Flow {
                        id: flowGrid
                        width: parent.width
                        spacing: 16
                        
                        Repeater {
                            model: wallpaperModel
                            
                            delegate: Rectangle {
                                width: 192
                                height: 132
                                radius: 8
                                color: gridMouse.containsMouse ? "#313244" : "#181825"
                                border.color: gridMouse.containsMouse ? "#898989" : "transparent" 
                                border.width: 1

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    source: "file://" + model.fullPath
                                    fillMode: Image.PreserveAspectCrop
                                    clip: true
                                }

                                MouseArea {
                                    id: gridMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        wallpaperSetter.command = [
                                            "awww", "img", model.fullPath,
                                            "--transition-type", "wipe",
                                            "--transition-step", "16"
                                        ];
                                        wallpaperSetter.running = true;
                                        
                                        // 🎯 Clear everything globally on execute
                                        rootScope.dismissAll();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 🏃 BACKGROUND EXECUTOR
    Process {
        id: wallpaperSetter
        running: false
    }
}
