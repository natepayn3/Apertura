import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Item {
    id: wallpaperModuleRoot
    implicitWidth: 32
    implicitHeight: 32

    property string wallpaperDir: ""
    property bool menuOpen: false
    property point globalMousePos: Qt.point(-1, -1)

    ListModel { id: wallpaperModel }

    Component.onCompleted: {
        wallpaperDir = Quickshell.env("HOME") + "/Pictures/Wallpapers";
        wallpaperScanner.command = ["sh", "-c", "ls " + wallpaperDir];
        wallpaperScanner.running = true;
    }

    function toggleMenu(): void { drawerTemplate.isOpen = !drawerTemplate.isOpen; }
    function closeMenu(): void { drawerTemplate.isOpen = false; }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                closeMenu();
            }
        }
    }

    function populateWallpapers(rawText) {
        wallpaperModel.clear();
        let lines = rawText.split("\n");
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (line !== "") {
                wallpaperModel.append({ fileName: line, fullPath: wallpaperDir + "/" + line });
            }
        }
        wallpaperListView.activeKeyIndex = -1;
        wallpaperListView.logicalMouseIndexStore = -1;
    }

    Process {
        id: wallpaperScanner
        command: ["true"]
        running: false
        stdout: StdioCollector { onTextChanged: populateWallpapers(text); }
    }

    Rectangle {
        id: triggerButton
        anchors.fill: parent
        radius: 0 
        color: "transparent" // Set to transparent base

        Text {
            anchors.centerIn: parent
            text: "wallpaper"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 26
            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
        }

        // Add this overlay to match the tint behavior
        Rectangle {
            id: hoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: wallpaperMouseArea.containsMouse ? 0.3 : 0.0
            z: 1 // Sits above base, below text
        }

        MouseArea {
            id: wallpaperMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: wallpaperItem.barHeight
        modalToken: "wallpaper"
        anchorTop: true

        onIsOpenChanged: {
            if (isOpen) {
                wallpaperModuleRoot.menuOpen = true;
                globalMousePos = Qt.point(-1, -1);
                wallpaperListView.activeKeyIndex = -1;
                wallpaperListView.logicalMouseIndexStore = -1;
                wallpaperListView.positionViewAtBeginning();
                mainContainerLayout.forceActiveFocus();
            } else {
                wallpaperModuleRoot.menuOpen = false;
            }
        }

        MouseArea { anchors.fill: parent; onPressed: (mouse) => mouse.accepted = true }

        ColumnLayout {
            id: mainContainerLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) { closeMenu(); event.accepted = true; }
                else if (event.key === Qt.Key_Down) {
                    wallpaperListView.logicalMouseIndexStore = -1;
                    if (wallpaperListView.activeKeyIndex === -1) wallpaperListView.activeKeyIndex = 0;
                    else if (wallpaperListView.activeKeyIndex < wallpaperListView.count - 1) wallpaperListView.activeKeyIndex++;
                    wallpaperListView.positionViewAtIndex(wallpaperListView.activeKeyIndex, ListView.Contain);
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Up) {
                    wallpaperListView.logicalMouseIndexStore = -1;
                    if (wallpaperListView.activeKeyIndex > 0) wallpaperListView.activeKeyIndex--;
                    wallpaperListView.positionViewAtIndex(wallpaperListView.activeKeyIndex, ListView.Contain);
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    let finalTarget = wallpaperListView.activeKeyIndex !== -1 ? wallpaperListView.activeKeyIndex : wallpaperListView.activeMouseIndex;
                    if (finalTarget >= 0 && finalTarget < wallpaperListView.count) {
                        let targetWallpaper = wallpaperModel.get(finalTarget);
                        wallpaperSetter.command = ["awww", "img", targetWallpaper.fullPath, "--transition-type", "wipe", "--transition-step", "16", "--transition-duration", "1"];
                        wallpaperSetter.running = true;
                        matugenSetter.command = [
                            "sh", "-c",
                            "mkdir -p " + Quickshell.env("HOME") + "/.config/quickshell/Apertura/Colors && matugen image \"" + targetWallpaper.fullPath + "\" -m dark --source-color-index 0 --dry-run --json hex > " + Quickshell.env("HOME") + "/.config/quickshell/Apertura/Colors/colors.json"
                        ];
                        matugenSetter.running = true;
                        closeMenu();
                    }
                    event.accepted = true;
                }
            }

            Text {
                text: "Wallpapers"
                font.family: "Rubik"
                font.pixelSize: 18
                font.weight: Font.Bold 
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: 10
            }

            ListView {
                id: wallpaperListView
                Layout.fillWidth: true
                Layout.fillHeight: true 
                clip: true
                spacing: 12
                model: wallpaperModel
                boundsBehavior: Flickable.StopAtBounds

                property int activeKeyIndex: -1
                property int logicalMouseIndexStore: -1
                property int activeMouseIndex: (activeKeyIndex === -1) ? logicalMouseIndexStore : -1

                delegate: Item {
                    width: wallpaperListView.width
                    height: 150
                    Rectangle {
                        width: 260
                        height: 150
                        anchors.horizontalCenter: parent.horizontalCenter
                        radius: 0 
                        readonly property bool isHighlighted: (wallpaperListView.activeKeyIndex === index && mainContainerLayout.activeFocus) || (wallpaperListView.activeMouseIndex === index)
                        color: isHighlighted ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "#11111b"
                        border.color: isHighlighted ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : "transparent"
                        border.width: 1

                        Image {
                            anchors.fill: parent; anchors.margins: 4
                            source: "file://" + model.fullPath
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                            cache: true
                            asynchronous: true
                            sourceSize.width: 260
                            sourceSize.height: 150
                        }
                    }

                    MouseArea {
                        id: gridMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        function verifyTruePointerAction() {
                            var currentGlobalPoint = gridMouse.mapToItem(wallpaperModuleRoot, gridMouse.mouseX, gridMouse.mouseY);
                            if (wallpaperModuleRoot.globalMousePos.x !== currentGlobalPoint.x || wallpaperModuleRoot.globalMousePos.y !== currentGlobalPoint.y) {
                                wallpaperModuleRoot.globalMousePos = currentGlobalPoint;
                                return true;
                            }
                            return false;
                        }
                        onEntered: { if (verifyTruePointerAction()) { wallpaperListView.activeKeyIndex = -1; wallpaperListView.logicalMouseIndexStore = index; } }
                        onPositionChanged: { if (verifyTruePointerAction()) { if (wallpaperListView.logicalMouseIndexStore !== index) { wallpaperListView.activeKeyIndex = -1; wallpaperListView.logicalMouseIndexStore = index; } } }
                        onExited: { if (wallpaperListView.logicalMouseIndexStore === index) { wallpaperListView.logicalMouseIndexStore = -1; } }
                        onClicked: { 
                            wallpaperSetter.command = ["awww", "img", model.fullPath, "--transition-type", "wipe", "--transition-step", "16", "--transition-duration", "1"];
                            wallpaperSetter.running = true; 
                            matugenSetter.command = [
                                "sh", "-c",
                                "mkdir -p " + Quickshell.env("HOME") + "/.config/quickshell/Apertura/Colors && matugen image \"" + model.fullPath + "\" -m dark --source-color-index 0 --dry-run --json hex > " + Quickshell.env("HOME") + "/.config/quickshell/Apertura/Colors/colors.json"
                            ];
                            matugenSetter.running = true;
                            closeMenu(); 
                        }
                    }
                }
            }
        }

        Process { id: wallpaperSetter; command: ["true"]; running: false }
        Process {
            id: matugenSetter
            command: ["true"]
            running: false
            onExited: (exitCode, exitStatus) => { if (exitCode === 0) rootScope.theme.reloadTheme(); }
        }
    }
}
