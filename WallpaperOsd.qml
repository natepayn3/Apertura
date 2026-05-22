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
        // 🔒 FIXED: Reset the targets synchronously BEFORE requesting the window map
        wallpaperCard.targetX = -655;
        wallpaperCard.targetOpacity = 0.0;

        rootScope.requestOpen(wallpaperModal);
        menuOpen = true;

        // 🔒 FIXED: Let the sequential animation controller handle the entry delta steps cleanly
        slideInAnimation.start();

        wallpaperScanner.running = false;
        wallpaperScanner.running = true;
    }

    function closeMenu(): void {
        // Animate out while still visible
        wallpaperCard.targetX = -655;
        wallpaperCard.targetOpacity = 0.0;

        closeTimer.start();
    }

    // 🔄 GLOBAL CLEANUP LISTENER
    Connections {
        target: rootScope

        function onActiveModalChanged() {
            if (rootScope.activeModal !== wallpaperModal && menuOpen) {
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

        color: wallpaperMouseArea.containsMouse
               ? "#313244"
               : "transparent"

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
            if (visible) {
                wallpaperCard.forceActiveFocus();
            }
        }

        // 🌫 BACKDROP
        MouseArea {
            anchors.fill: parent
            onClicked: closeMenu()
        }

        // 📦 MAIN CARD
        Rectangle {
            id: wallpaperCard

            width: 650
            height: 480

            anchors.top: parent.top
            anchors.topMargin: 12

            // Mutable animation targets
            property int targetX: -655
            property real targetOpacity: 0.0

            x: targetX
            opacity: targetOpacity

            // 🔒 FIXED: Dedicated entry script sequence guarantees baseline layout tracking values are caught
            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 } // Holds back just enough for Wayland window map to settle
                ParallelAnimation {
                    NumberAnimation { target: wallpaperCard; property: "targetX"; to: 5; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: wallpaperCard; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            // ✨ SLIDE (Handles implicit property drift modifications on closeMenu)
            Behavior on x {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            // ✨ FADE (Handles implicit property drift modifications on closeMenu)
            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutQuad
                }
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

            // Prevent click-through
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

                // 🏷 HEADER
                Text {
                    text: "Select Wallpaper"

                    font.family: "Rubik"
                    font.pixelSize: 18
                    font.weight: Font.Bold

                    color: "#cdd6f4"

                    Layout.leftMargin: 2
                }

                // 📜 SCROLLABLE WALLPAPER GRID
                Flickable {
                    id: scrollContainer

                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    contentHeight: flowGrid.childrenRect.height

                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

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

                                color: gridMouse.containsMouse
                                       ? "#313244"
                                       : "#181825"

                                border.color: gridMouse.containsMouse
                                              ? "#898989"
                                              : "transparent"

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
        }
    }

    // 🏃 WALLPAPER SETTER
    Process {
        id: wallpaperSetter

        running: false
    }
}
