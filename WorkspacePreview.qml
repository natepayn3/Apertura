import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: previewRoot

    property int targetWorkspace: -1
    property bool active: false
    property var theme

    property var liveClientJson: []

    readonly property int neededWidth: viewportFrame.width + 32

    onTargetWorkspaceChanged: {
        if (targetWorkspace !== -1) {
            previewRoot.active = false;
            updateGeometryMap();
            retriggerTimer.restart();
        } else {
            previewRoot.active = false;
        }
    }

    onActiveChanged: {
        if (active) {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            previewRoot.updateGeometryMap();
        }
    }

    Timer {
        id: hoverRefreshTimer
        interval: 50
        running: previewRoot.active
        repeat: true
        property int ticks: 0

        onRunningChanged: {
            if (running) ticks = 0;
        }

        onTriggered: {
            previewRoot.updateGeometryMap();
            ticks++;
            if (ticks >= 6) {
                running = false;
            }
        }
    }

    Timer {
        id: retriggerTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: previewRoot.active = true;
    }

    function updateGeometryMap() {
        if (targetWorkspace === -1) return;
        clientQueryProcess.running = true;
    }

    Timer {
        id: debounceTimer
        interval: 50
        running: false
        repeat: false
        onTriggered: previewRoot.updateGeometryMap()
    }

    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onRawEvent(event) {
            debounceTimer.restart();
        }
    }

    Process {
        id: clientQueryProcess
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText || cleanText === "[]") return;
                try {
                    previewRoot.liveClientJson = JSON.parse(cleanText);
                } catch(e) {}
            }
        }
    }

    Process {
        id: switchWorkspace
        running: false
    }

    height: viewportFrame.isVertical ? 560 : 300
    width: neededWidth

    Text {
        id: titleLabel
        text: "Workspace " + previewRoot.targetWorkspace
        font.family: "Rubik"
        font.pixelSize: 14
        font.weight: Font.Bold
        color: previewRoot.theme ? previewRoot.theme.theme_fg : "#89b4fa" 
        x: 16
        y: 14
    }

    Rectangle {
        id: headerDivider
        width: viewportFrame.width
        height: 1
        color: previewRoot.theme ? previewRoot.theme.theme_outline : "#313244"
        x: 16
        y: 38
    }

    Rectangle {
        id: viewportFrame
        height: parent.height - 70
        x: 16
        y: 50
        color: Qt.rgba(0, 0, 0, 0.4)
        border.width: 0
        radius: 0
        clip: true

        property var workspaceWindows: previewRoot.liveClientJson.filter(w => w.workspace.id === previewRoot.targetWorkspace)

        property var activeWsObj: Hyprland.workspaces.values.find(ws => ws.id === previewRoot.targetWorkspace) || null
        property var wsMonitor: activeWsObj ? activeWsObj.monitor : (Hyprland.activeMonitor || null)

        property var calculatedBounds: {
            if (!workspaceWindows || workspaceWindows.length === 0) {
                return { "w": 1920, "h": 1080, "isVertical": false, "originX": 0, "originY": 0 };
            }
            
            let minX = Infinity, minY = Infinity;
            let maxX = -Infinity, maxY = -Infinity;
            
            for (let i = 0; i < workspaceWindows.length; i++) {
                let win = workspaceWindows[i];
                if (!win.at || !win.size) continue;
                
                if (win.at[0] < minX) minX = win.at[0];
                if (win.at[1] < minY) minY = win.at[1];
                
                let rightEdge = win.at[0] + win.size[0];
                let bottomEdge = win.at[1] + win.size[1];
                
                if (rightEdge > maxX) maxX = rightEdge;
                if (bottomEdge > maxY) maxY = bottomEdge;
            }
            
            let spanX = maxX - minX;
            let spanY = maxY - minY;
            let verticalDetected = spanY > spanX;
            
            let normW = verticalDetected ? 1080 : 1920;
            let normH = verticalDetected ? 1920 : 1080;
            
            if (spanX > 0 && Math.abs(spanX - normW) > 100) normW = spanX;
            if (spanY > 0 && Math.abs(spanY - normH) > 100) normH = spanY;
            
            return {
                "w": normW,
                "h": normH,
                "isVertical": verticalDetected,
                "originX": minX,
                "originY": minY
            };
        }

        property real monitorW: calculatedBounds.w
        property real monitorH: calculatedBounds.h
        property bool isVertical: calculatedBounds.isVertical

        property real monitorX: calculatedBounds.originX
        property real monitorY: calculatedBounds.originY

        width: Math.round(height * (monitorW / monitorH))

        property real scaleX: width / monitorW
        property real scaleY: height / monitorH

        Image {
            anchors.fill: parent
            source: viewportFrame.wsMonitor && typeof WallpaperService !== "undefined" ? WallpaperService.getWallpaper(viewportFrame.wsMonitor.name) : ""
            fillMode: Image.PreserveAspectCrop
            visible: source != ""
            opacity: 0.45
        }

        Repeater {
            model: viewportFrame.workspaceWindows

            delegate: Rectangle {
                id: windowDelegate
                property real winX: modelData.at ? modelData.at[0] : 0
                property real winY: modelData.at ? modelData.at[1] : 0
                property real winW: modelData.size ? modelData.size[0] : 0
                property real winH: modelData.size ? modelData.size[1] : 0

                x: (winX - viewportFrame.monitorX) * viewportFrame.scaleX
                y: (winY - viewportFrame.monitorY) * viewportFrame.scaleY
                
                width: Math.max(4, winW * viewportFrame.scaleX)
                height: Math.max(4, winH * viewportFrame.scaleY)

                visible: modelData.mapped

                color: previewRoot.theme ? Qt.alpha(previewRoot.theme.theme_bg, 0.8) : "#cc11111b"
                border.color: previewRoot.theme ? previewRoot.theme.theme_primary : "#89b4fa"
                border.width: 1
                radius: 0
                clip: true

                property var wlToplevel: {
                    if (!modelData || !modelData.address) return null;
                    
                    let tracker = clientQueryProcess.running;
                    let targetAddr = modelData.address.trim().toLowerCase();

                    let match = Hyprland.toplevels.values.find(t => {
                        if (!t.lastIpcObject || !t.lastIpcObject.address) return false;
                        return t.lastIpcObject.address.trim().toLowerCase() === targetAddr;
                    });
                    if (match && match.wayland) return match.wayland;
                    
                    if (viewportFrame.activeWsObj) {
                        let localMatch = viewportFrame.activeWsObj.toplevels.values.find(t => {
                            if (!t.lastIpcObject || !t.lastIpcObject.address) return false;
                            return t.lastIpcObject.address.trim().toLowerCase() === targetAddr;
                        });
                        if (localMatch && localMatch.wayland) return localMatch.wayland;
                    }
                    return null;
                }

                Loader {
                    anchors.fill: parent
                    active: windowDelegate.wlToplevel !== null
                    asynchronous: true
                    
                    opacity: status === Loader.Ready ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    sourceComponent: ScreencopyView {
                        width: parent.width
                        height: parent.height
                        captureSource: windowDelegate.wlToplevel
                        live: true
                        paintCursor: false
                        constraintSize: Qt.size(parent.width, parent.height)
                    }
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Math.min(14, parent.height * 0.25)
                    color: "#cc11111b"
                    visible: parent.height > 20 && parent.width > 35
                    z: 10 

                    Text {
                        text: (modelData.title && modelData.title.trim() !== "" && modelData.title !== "~") ? modelData.title : (modelData.class || "")
                        font.family: "Rubik"
                        font.pixelSize: 8
                        font.weight: Font.Bold
                        color: "#ffffff"
                        anchors.centerIn: parent
                        width: parent.width - 4
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    MouseArea {
        id: clickSurface
        anchors.fill: viewportFrame
        cursorShape: Qt.PointingHandCursor
        z: 20
        
        propagateComposedEvents: true
        
        onPressed: (mouse) => mouse.accepted = true
        onReleased: (mouse) => mouse.accepted = true
        
        onPositionChanged: (mouse) => mouse.accepted = false

        onClicked: {
            if (previewRoot.targetWorkspace !== -1) {
                switchWorkspace.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + previewRoot.targetWorkspace + "\" })"];
                switchWorkspace.running = true;
            }
        }
    }
}
