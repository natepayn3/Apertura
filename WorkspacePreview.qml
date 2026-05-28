import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

PanelWindow {
    id: previewOverlayModal
    
    // 🧠 VISUAL STATE TRACKER
    property var targetScreen: null
    screen: targetScreen
    visible: menuOpen

    property bool active: false
    property int workspaceId: 1
    property var windowData: []
    property bool menuOpen: false

    // Predictable, stable dimensions for the outer OSD menu frame
    implicitWidth: 340
    implicitHeight: 230

    anchors {
        left: true
    }
    
    WlrLayershell.margins {
        left: 54
    }
    
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    MouseArea {
        anchors.fill: parent
        z: 1
        onPressed: forcedClose()
    }

    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false; repeat: false
        onTriggered: forcedClose()
    }

    Timer {
        id: closeTimer
        interval: 180; repeat: false
        onTriggered: { previewOverlayModal.menuOpen = false; }
    }

    // 🔓 ANIMATED CONTEXT INTERFACING
    function openMenu(): void {
        slideInAnimation.stop();
        slideOutAnimation.stop();

        popupMenuFrame.targetX = -340; 
        popupMenuFrame.targetOpacity = 0.0;

        rootScope.requestOpen("workspace_preview");
        menuOpen = true;
        
        layoutIpcQuery.running = false;
        layoutIpcQuery.running = true;

        slideInAnimation.start();
        osdAutohideTimer.restart();
        popupMenuFrame.forceActiveFocus();
    }

    function closeMenu(): void {
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop();
            return;
        }
    }

    function forcedClose(): void {
        osdAutohideTimer.stop();
        slideInAnimation.stop();
        slideOutAnimation.stop();
        slideOutAnimation.start();
        closeTimer.start();
    }

    function checkUserActivity() {
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (menuOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    function handleMouseLeave() {
        checkUserActivity();
        if (!active) {
            forcedClose();
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (menuOpen && rootScope.activeModal !== "workspace_preview" && !slideInAnimation.running) {
                forcedClose();
            }
        }
    }

    onActiveChanged: {
        if (active) openMenu(); else closeMenu();
    }

    // UNIVERSAL IPC LAYOUT ENGINE
    Process {
        id: layoutIpcQuery
        command: ["hyprctl", "clients", "-j"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var rawJson = layoutIpcQuery.stdout.text;
                    if (!rawJson || rawJson.trim() === "") return;
                    
                    var clients = JSON.parse(rawJson);
                    var activeWsStr = String(previewOverlayModal.workspaceId);
                    var parsedWindows = [];
                    
                    var monitorWidth = previewOverlayModal.screen.width || 1920;
                    var monitorHeight = previewOverlayModal.screen.height || 1080;
                    var mX = previewOverlayModal.screen.x || 0;
                    var mY = previewOverlayModal.screen.y || 0;

                    for (var i = 0; i < clients.length; i++) {
                        var client = clients[i];
                        var ws = client.workspace || {};
                        var wsId = (typeof ws === 'object') ? ws.id : ws;

                        if (String(wsId) === activeWsStr) {
                            var rawX = client.at[0];
                            var rawY = client.at[1];
                            var w = client.size[0];
                            var h = client.size[1];

                            if (w <= 0 || h <= 0) continue;

                            var localX = rawX - mX;
                            var localY = rawY - mY;
                            
                            var rawClass = client.class || "Window";
                            var normClass = rawClass.toLowerCase().trim();

                            // ⚡ THE ICON THEME ALIAS MAPPER
                            // Strips URL handlers and sub-class strings to ensure theme match execution
                            if (normClass.indexOf("vscodium") !== -1 || normClass === "codium") {
                                normClass = "vscodium";
                            } else if (normClass === "kitty-dropterm") {
                                normClass = "kitty";
                            } else if (normClass.indexOf("chrome") !== -1) {
                                normClass = "google-chrome";
                            }

                            parsedWindows.push({
                                "class": rawClass,
                                "icon_class": normClass, // Store normalized alias reference string
                                "title": client.title || "",
                                "is_focused": client.focusHistoryID === 0,
                                "x_pct": Math.max(0.0, Math.min(1.0, localX / monitorWidth)),
                                "y_pct": Math.max(0.0, Math.min(1.0, localY / monitorHeight)),
                                "w_pct": Math.max(0.0, Math.min(1.0, w / monitorWidth)),
                                "h_pct": Math.max(0.0, Math.min(1.0, h / monitorHeight))
                            });
                        }
                    }
                    previewOverlayModal.windowData = parsedWindows;
                } catch (e) {
                    console.error("Layout engine parser fault: " + e);
                }
            }
        }
    }

    // WORKSPACE SWITCHER IPC
    Process {
        id: workspaceSwitcherIpc
        command: ["hyprctl", "dispatch", "workspace", String(previewOverlayModal.workspaceId)]
    }

    Timer { 
        interval: 1000; running: previewOverlayModal.active; repeat: true; 
        onTriggered: { layoutIpcQuery.running = false; layoutIpcQuery.running = true; }
    }

    Item {
        id: animationMask
        anchors.fill: parent
        clip: true 
        z: 2

        Rectangle {
            id: popupMenuFrame
            width: 340
            height: 230
            
            property int targetX: -340
            property real targetOpacity: 0.0
            
            x: targetX
            opacity: targetOpacity
            focus: true

            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupMenuFrame; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupMenuFrame; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            SequentialAnimation {
                id: slideOutAnimation
                ParallelAnimation {
                    NumberAnimation { target: popupMenuFrame; property: "targetX"; to: -340; duration: 160; easing.type: Easing.InCubic }
                    NumberAnimation { target: popupMenuFrame; property: "targetOpacity"; to: 0.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            color: "#9911111b"

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    forcedClose();
                    event.accepted = true;
                }
            }

            Text { 
                id: headerTextLabel
                text: "Workspace " + previewOverlayModal.workspaceId
                font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#ffffff" 
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 12
            }

            Rectangle { 
                id: horizontalDividerLine
                height: 1; color: "#26ffffff" 
                anchors.top: headerTextLabel.bottom
                anchors.topMargin: 6
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 12; anchors.rightMargin: 12
            }

            Item {
                id: canvasCenteringWrapper
                anchors.top: horizontalDividerLine.bottom
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 6
                anchors.bottomMargin: 12
                anchors.leftMargin: 12
                anchors.rightMargin: 12

                Item {
                    id: previewCanvasContainer
                    anchors.centerIn: parent
                    
                    height: parent.height
                    width: Math.round(parent.height * (previewOverlayModal.screen.width / previewOverlayModal.screen.height))

                    Rectangle {
                        anchors.fill: parent
                        color: "#1e1e2e"
                        radius: 6
                    }
                    
                    Repeater {
                        id: windowRepeater
                        model: previewOverlayModal.windowData
                        
                        Item {
                            x: Math.round(modelData.x_pct * previewCanvasContainer.width)
                            y: Math.round(modelData.y_pct * previewCanvasContainer.height)
                            width: Math.round(modelData.w_pct * previewCanvasContainer.width)
                            height: Math.round(modelData.h_pct * previewCanvasContainer.height)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                
                                color: modelData.is_focused ? "#313244" : "#181825"
                                border.width: modelData.is_focused ? 2 : 1
                                border.color: modelData.is_focused ? "#cba6f7" : "#45475a"
                                radius: 4
                                
                                ColumnLayout {
                                    anchors.centerIn: parent
                                    width: parent.width - 12
                                    spacing: 4

                                    Image {
                                        Layout.alignment: Qt.AlignHCenter
                                        source: "image://icon/" + modelData.icon_class // Direct binding routing to the mapped string
                                        sourceSize.width: Math.min(24, parent.parent.height * 0.4)
                                        sourceSize.height: Math.min(24, parent.parent.height * 0.4)
                                        cache: true
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.class
                                        color: modelData.is_focused ? "#cdd6f4" : "#a6adc8"
                                        font.family: "Rubik"
                                        font.weight: modelData.is_focused ? Font.Medium : Font.Normal
                                        font.pixelSize: Math.max(8, Math.min(11, parent.parent.width * 0.09))
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Empty Workspace"
                        color: "#585b70"
                        font.family: "Rubik"
                        font.pixelSize: 12
                        visible: windowRepeater.count === 0
                    }

                    MouseArea {
                        anchors.fill: parent
                        z: 3
                        onClicked: {
                            workspaceSwitcherIpc.running = false;
                            workspaceSwitcherIpc.running = true;
                            forcedClose();
                        }
                    }
                }
            }

            MouseArea { 
                id: cardHoverTracker
                anchors.fill: parent; hoverEnabled: true
                onPressed: (mouse) => { mouse.accepted = false; checkUserActivity(); } 
                onContainsMouseChanged: {
                    if (!containsMouse) {
                        handleMouseLeave();
                    } else {
                        checkUserActivity();
                    }
                }
            }
        }
    }
}
