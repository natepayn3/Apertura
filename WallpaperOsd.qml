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

    // 🎯 HOME DIRECTORY CONFIGURATION PATH
    property string wallpaperDir: ""

    // Controls actual PanelWindow visibility
    property bool menuOpen: false

    ListModel {
        id: wallpaperModel
    }

    // 🔒 ROOT HARDWARE COORDINATE TRACKERS
    property point globalMousePos: Qt.point(-1, -1)

    // 🎯 THE FIX: Maps user space variables inside runtime subshell evaluations atomically
    Component.onCompleted: {
        // Fallback target context engine to track image file loops cleanly inside your lists
        wallpaperDir = Quickshell.env("HOME") + "/Pictures/Wallpapers";
        
        // Pass expansion arrays safely to the scanner engine
        wallpaperScanner.command = ["sh", "-c", "ls " + wallpaperDir];
        
        // Execute background worker loops
        wallpaperScanner.running = true;
    }

    // 🎬 CLOSE FINALIZER
    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            wallpaperModuleRoot.menuOpen = false;
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
        globalMousePos = Qt.point(-1, -1);

        wallpaperListView.activeKeyIndex = -1;
        wallpaperListView.logicalMouseIndexStore = -1;

        wallpaperCard.targetX = -216;
        wallpaperCard.targetOpacity = 0.0;

        rootScope.requestOpen(wallpaperModal);
        menuOpen = true;

        slideRightAnimation.start();

        if (wallpaperModel.count === 0 && wallpaperScanner.command && wallpaperScanner.command.length > 1) {
            wallpaperScanner.running = false;
            wallpaperScanner.running = true;
        }
    }

    function closeMenu(): void {
        wallpaperCard.targetX = -216;
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
        wallpaperListView.activeKeyIndex = -1;
        wallpaperListView.logicalMouseIndexStore = -1;
    }

    // 🔄 WALLPAPER DIRECTORY SCANNER
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

    // 🔘 TRIGGER BUTTON
    Rectangle {
        id: triggerButton
        anchors.fill: parent
        radius: 0 
        color: wallpaperMouseArea.containsMouse ? "#26ffffff" : "transparent"

        Text {
            anchors.centerIn: parent
            text: "󰸉"
            font.family: "Rubik"
            font.pixelSize: 24
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

    // 🪟 WALLPAPER WINDOW
    PanelWindow {
        id: wallpaperModal
        visible: wallpaperModuleRoot.menuOpen

        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-wallpapers"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        WlrLayershell.margins.left: 0; WlrLayershell.margins.right: 0; WlrLayershell.margins.bottom: 0; WlrLayershell.margins.top: 0

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

        // 📦 VERTICAL PANE CONTAINER
        Rectangle {
            id: wallpaperCard
            width: 216
            
            anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.topMargin: 12; anchors.bottomMargin: 12; anchors.left: parent.left
            
            property int targetX: -216
            property real targetOpacity: 0.0
            anchors.leftMargin: targetX; opacity: targetOpacity

            SequentialAnimation {
                id: slideRightAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: wallpaperCard; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: wallpaperCard; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            Behavior on anchors.leftMargin { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

            color: "#9911111b"
            border.width: 0; border.color: "transparent"; focus: true
            topLeftRadius: 0; bottomLeftRadius: 0; topRightRadius: 0; bottomRightRadius: 0

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
                anchors.fill: parent; anchors.topMargin: 16; anchors.bottomMargin: 16; spacing: 12

                Text {
                    text: "Wallpapers"
                    font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#ffffff"
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
                }

                ListView {
                    id: wallpaperListView
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 12
                    model: wallpaperModel; boundsBehavior: Flickable.StopAtBounds

                    property int activeKeyIndex: -1
                    property int logicalMouseIndexStore: -1
                    property int activeMouseIndex: (activeKeyIndex === -1) ? logicalMouseIndexStore : -1

                    delegate: Item {
                        width: wallpaperListView.width; height: 132

                        Rectangle {
                            width: 192; height: 132
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
