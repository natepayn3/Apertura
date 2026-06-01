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

    property string wallpaperDir: ""
    property bool menuOpen: false
    property point globalMousePos: Qt.point(-1, -1)
    property bool windowAlive: false

    ListModel {
        id: wallpaperModel
    }

    Component.onCompleted: {
        wallpaperDir = Quickshell.env("HOME") + "/Pictures/Wallpapers";
        wallpaperScanner.command = ["sh", "-c", "ls " + wallpaperDir];
        wallpaperScanner.running = true;
    }

    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        globalMousePos = Qt.point(-1, -1);
        wallpaperListView.activeKeyIndex = -1;
        wallpaperListView.logicalMouseIndexStore = -1;
        
        rootScope.requestOpen("wallpaper");
        windowAlive = true;
        menuOpen = true;
    }

    function closeMenu(): void {
        menuOpen = false;
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== "wallpaper" && menuOpen) {
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
                wallpaperModel.append({
                    fileName: line,
                    fullPath: wallpaperDir + "/" + line
                });
            }
        }
        wallpaperListView.activeKeyIndex = -1;
        wallpaperListView.logicalMouseIndexStore = -1;
    }

    Process {
        id: wallpaperScanner
        command: ["true"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                populateWallpapers(text);
            }
        }
    }

    Rectangle {
        id: triggerButton
        anchors.fill: parent
        radius: 0 
        color: wallpaperMouseArea.containsMouse ? "#26ffffff" : "transparent"

        Text {
            anchors.centerIn: parent
            text: "wallpaper"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 26
            color: "#ffffff"
        }

        MouseArea {
            id: wallpaperMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: wallpaperModal
        visible: wallpaperModuleRoot.windowAlive
        anchors.top: parent.top; anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-wallpapers"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && wallpaperModuleRoot.menuOpen) {
                wallpaperListView.activeKeyIndex = -1;
                wallpaperListView.logicalMouseIndexStore = -1;
                wallpaperListView.positionViewAtBeginning();
                wallpaperCard.forceActiveFocus();
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: closeMenu()
        }

        Rectangle {
            id: wallpaperCard
            width: 290
            anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.topMargin: 12; anchors.bottomMargin: 12

            states: [
                State {
                    name: "visible"
                    when: wallpaperModuleRoot.menuOpen
                    PropertyChanges { target: wallpaperCard; x: 0; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: !wallpaperModuleRoot.menuOpen
                    PropertyChanges { target: wallpaperCard; x: -310; opacity: 0.0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "visible"
                    ParallelAnimation {
                        NumberAnimation { property: "x"; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.OutCubic }
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { property: "x"; duration: 350; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.InCubic }
                        }
                        ScriptAction {
                            script: { wallpaperModuleRoot.windowAlive = false; }
                        }
                    }
                }
            ]

            color: "#9911111b"
            border.width: 0; border.color: "transparent"; focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Down) {
                    wallpaperListView.logicalMouseIndexStore = -1;
                    if (wallpaperListView.activeKeyIndex === -1) {
                        wallpaperListView.activeKeyIndex = 0;
                    } else if (wallpaperListView.activeKeyIndex < wallpaperListView.count - 1) {
                        wallpaperListView.activeKeyIndex++;
                    }
                    wallpaperListView.positionViewAtIndex(wallpaperListView.activeKeyIndex, ListView.Contain);
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Up) {
                    wallpaperListView.logicalMouseIndexStore = -1;
                    if (wallpaperListView.activeKeyIndex > 0) {
                        wallpaperListView.activeKeyIndex--;
                    }
                    wallpaperListView.positionViewAtIndex(wallpaperListView.activeKeyIndex, ListView.Contain);
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    let finalTarget = wallpaperListView.activeKeyIndex !== -1 ? wallpaperListView.activeKeyIndex : wallpaperListView.activeMouseIndex;
                    if (finalTarget >= 0 && finalTarget < wallpaperListView.count) {
                        let targetWallpaper = wallpaperModel.get(finalTarget);
                        wallpaperSetter.command = ["awww", "img", targetWallpaper.fullPath, "--transition-type", "wipe", "--transition-step", "16"];
                        wallpaperSetter.running = true;
                        closeMenu();
                    }
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: (mouse) => mouse.accepted = true
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 8

                Text {
                    text: "Wallpapers"
                    font.family: "Rubik"; font.pixelSize: 18; font.weight: Font.Bold; color: "#ffffff"
                    Layout.alignment: Qt.AlignLeft
                    Layout.leftMargin: 10
                    Layout.bottomMargin: 2
                    Layout.topMargin: 4
                }

                ListView {
                    id: wallpaperListView
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 12
                    model: wallpaperModel; boundsBehavior: Flickable.StopAtBounds

                    property int activeKeyIndex: -1
                    property int logicalMouseIndexStore: -1
                    property int activeMouseIndex: (activeKeyIndex === -1) ? logicalMouseIndexStore : -1

                    delegate: Item {
                        width: wallpaperListView.width; height: 150

                        Rectangle {
                            width: 260; height: 150
                            anchors.horizontalCenter: parent.horizontalCenter; radius: 0 
                            
                            readonly property bool isHighlighted: (wallpaperListView.activeKeyIndex === index && wallpaperCard.activeFocus) || 
                                                                  (wallpaperListView.activeMouseIndex === index)

                            color: isHighlighted ? "#26ffffff" : "#11111b"
                            border.color: isHighlighted ? "#ffffff" : "transparent"
                            border.width: 1

                            Image {
                                anchors.fill: parent; anchors.margins: 4
                                source: "file://" + model.fullPath
                                fillMode: Image.PreserveAspectCrop; clip: true
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
                            onClicked: { wallpaperSetter.command = ["awww", "img", model.fullPath, "--transition-type", "wipe", "--transition-step", "16"]; wallpaperSetter.running = true; closeMenu(); }
                        }
                    }
                }
            }
        }
    }

    Process { id: wallpaperSetter; command: ["true"]; running: false }
}
