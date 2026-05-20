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
        wallpaperModal.visible = !wallpaperModal.visible;
        if (wallpaperModal.visible) {
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
            color: wallpaperMouseArea.containsMouse ? "#f5e0dc" : "#cdd6f4"
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

        MouseArea {
            anchors.fill: parent
            onPressed: wallpaperModal.visible = false
        }

        Rectangle {
            id: wallpaperCard
            width: 650
            height: 480
            x: 60 
            y: 10
            color: "#EE1e1e2e"
            border.color: "#313244"
            border.width: 1
            radius: 12

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    wallpaperModal.visible = false;
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                // 👇 BALANCED MARGINS: Forces matching structural bounding spaces on all sides
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
                    color: "#a6adc8"
                    Layout.leftMargin: 2 // Tiny text alignment offset match
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
                        // 👇 BALANCED SPACING: Distributes layout gaps symmetrically between column elements
                        spacing: 16
                        
                        Repeater {
                            model: wallpaperModel
                            
                            delegate: Rectangle {
                                // 📐 Explicitly balanced for 3 columns across 610px of content width
                                width: 192
                                height: 132
                                radius: 8
                                color: gridMouse.containsMouse ? "#313244" : "#181825"
                                border.color: gridMouse.containsMouse ? "#f5e0dc" : "transparent"
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
                                        wallpaperModal.visible = false;
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