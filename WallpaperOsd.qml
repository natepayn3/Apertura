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

    // Controls actual PanelWindow visibility
    property bool menuOpen: false

    ListModel {
        id: wallpaperModel
    }

    // 🎬 CLOSE FINALIZER
    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            wallpaperModuleRoot.menuOpen = false;
            rootScope.dismissAll();
        }
    }

    // 🔓 PUBLIC INTERFACE
    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        // Reset hidden left offsets and opacity before mapping (start compressed behind bar)
        wallpaperCard.targetX = -216;
        wallpaperCard.targetOpacity = 0.0;

        rootScope.requestOpen(wallpaperModal);
        menuOpen = true;

        // Run the smooth horizontal slide-right sequence
        slideRightAnimation.start();

        if (wallpaperModel.count === 0) {
            wallpaperScanner.running = false;
            wallpaperScanner.running = true;
        }
    }

    function closeMenu(): void {
        // Slide horizontally backward toward the bar on exit
        wallpaperCard.targetX = -216;
        wallpaperCard.targetOpacity = 0.0;

        closeTimer.start();
    }

    // 🔄 GLOBAL CLEANUP LISTENER
    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (menuOpen && rootScope.activeModal !== wallpaperModal && !slideRightAnimation.running) {
                closeMenu();
            }
        }
    }

    // 📦 LOAD WALLPAPERS
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

    // 🔄 WALLPAPER DIRECTORY SCANNER
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
        radius: 8
        color: wallpaperMouseArea.containsMouse ? "#313244" : "transparent"

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

    // 🪟 WALLPAPER WINDOW
    PanelWindow {
        id: wallpaperModal
        visible: wallpaperModuleRoot.menuOpen

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-wallpapers"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && wallpaperModuleRoot.menuOpen) {
                wallpaperCard.forceActiveFocus();
            }
        }

        // 🌫 BACKDROP
        MouseArea {
            anchors.fill: parent
            onClicked: closeMenu()
        }

        // 📦 VERTICAL PANE CONTAINER
        Rectangle {
            id: wallpaperCard

            width: 216
            height: 600
            
            // Lock the top margin flush to the bar alignment baseline geometry
            anchors.top: parent.top
            anchors.topMargin: 12
            
            // 🔒 FIXED: Driving horizontal emergence mapping via the left anchor offset track
            anchors.left: parent.left
            
            property int targetX: -216
            property real targetOpacity: 0.0

            anchors.leftMargin: targetX
            opacity: targetOpacity

            // ✨ HORIZONTAL SLIDE ENTRY SEQUENCE
            SequentialAnimation {
                id: slideRightAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: wallpaperCard; property: "targetX"; to: 5; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: wallpaperCard; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            // ✨ HORIZONTAL EXIT TRACKERS
            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            color: "#cc11111b"
            border.color: "#898989"
            border.width: 1
            radius: 12
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                spacing: 12

                // 🏷 HEADER
                Text {
                    text: "Wallpapers"
                    font.family: "Rubik"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: "#cdd6f4"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                // 📜 VERTICAL LIST VIEW
                ListView {
                    id: wallpaperListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 12
                    model: wallpaperModel
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        width: wallpaperListView.width
                        height: 132

                        Rectangle {
                            width: 192
                            height: 132
                            anchors.horizontalCenter: parent.horizontalCenter
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
                        }

                        MouseArea {
                            id: gridMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wallpaperSetter.command = [
                                    "awww",
                                    "img",
                                    model.fullPath,
                                    "--transition-type",
                                    "wipe",
                                    "--transition-step",
                                    "16"
                                ];
                                wallpaperSetter.running = true;
                                closeMenu();
                            }
                        }
                    }
                }
            }
        }
    }

    // 🏃 WALLPAPER SETTER
    Process {
        id: wallpaperSetter
        running: false
    }
}
