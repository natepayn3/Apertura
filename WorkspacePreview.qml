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

    // UNIVERSAL IPC ENGINE
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

                            // ⚡ Pass down the hex mapping address identifier string cleanly
                            parsedWindows.push({
                                "address": String(client.address || "").toLowerCase().trim(),
                                "class": client.class || "Window",
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
                        radius: 3
                        visible: windowRepeater.count === 0

                        Text {
                            anchors.centerIn: parent
                            text: "Empty Workspace"
                            color: "#a6adc8"
                            font.family: "Rubik"
                            font.pixelSize: 12
                        }
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
                                color: modelData.is_focused ? "#313244" : "#1e1e2e"
                                radius: 4
                                z: 0
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.class
                                    color: "#a6adc8"
                                    font.family: "Rubik"
                                    font.pixelSize: Math.min(11, parent.width * 0.12)
                                    elide: Text.ElideRight
                                    width: parent.width - 8
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: screencopyElement.status !== ScreencopyView.Ready
                                }
                            }

                            ScreencopyView {
                                id: screencopyElement
                                anchors.fill: parent
                                live: previewOverlayModal.menuOpen && previewOverlayModal.visible
                                z: 1

                                // ⚡ THE CORE ADDRESS MATCH FIX: Safely extract the hex address key 
                                // directly out of the base object description strings, bypassing custom layer blocks.
                                captureSource: {
                                    if (!modelData || !modelData.address) return null;
                                    
                                    var pool = ToplevelManager.toplevels.values;
                                    for (var i = 0; i < pool.length; i++) {
                                        var win = pool[i];
                                        if (win) {
                                            // Convert the internal engine context descriptor string into a clean matching hex signature
                                            var objectDescription = String(win).toLowerCase();
                                            if (objectDescription.indexOf(modelData.address) !== -1) {
                                                return win;
                                            }
                                        }
                                    }
                                    
                                    // Soft fallback path to prevent black boxes if a connection slips
                                    for (var j = 0; j < pool.length; j++) {
                                        var fallbackWin = pool[j];
                                        if (fallbackWin && fallbackWin.appId && fallbackWin.appId.toLowerCase() === modelData.class.toLowerCase()) {
                                            return fallbackWin;
                                        }
                                    }
                                    return null;
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: 1
                                border.color: "#414559"
                                radius: 4
                                z: 2
                            }
                        }
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