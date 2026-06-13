import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: previewRoot

    property int targetWorkspace: -1
    property bool active: targetWorkspace !== -1
    property var liveClientJson: []

    // Read-only state property string helper so shell.qml knows when the animation completes
    property string activeState: animatedContainer.state

    implicitWidth: active ? (viewportFrame.width + 28) : 0
    implicitHeight: active ? (viewportFrame.calculatedBounds.isVertical ? 380 : 200) : 0

    onTargetWorkspaceChanged: {
        if (targetWorkspace !== -1) {
            clientQueryProcess.running = true;
        } else {
            liveClientJson = [];
        }
    }

    Connections {
        target: Hyprland
        ignoreUnknownSignals: true
        function onRawEvent(event) { if (previewRoot.active) clientQueryProcess.running = true; }
    }

    Process {
        id: clientQueryProcess
        command: ["hyprctl", "clients", "-j"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText || cleanText === "[]") return;
                try { previewRoot.liveClientJson = JSON.parse(cleanText); } catch(e) {}
            }
        }
    }

    Process { id: switchWorkspace; running: false }

    function getCleanIconName(className) {
        if (!className) return "application-x-executable";
        let lowerClass = className.toLowerCase().trim();
        if (lowerClass.includes("chrome")) return "google-chrome";
        if (lowerClass.includes("kitty")) return "kitty";
        if (lowerClass.includes("terminal")) return "utilities-terminal";
        if (lowerClass.includes("codium")) return "vscodium";
        if (lowerClass.includes("code")) return "vscode";
        if (lowerClass.includes("signal")) return "signal-desktop";
        return lowerClass;
    }

    Item {
        id: animatedContainer
        width: previewRoot.implicitWidth
        height: previewRoot.implicitHeight

        states: [
            State {
                name: "hidden"
                when: !previewRoot.active
                PropertyChanges { target: animatedContainer; opacity: 0.0 }
                PropertyChanges { 
                    target: animatedContainer; 
                    x: rootShell.barPosition === "left" ? -width : (rootShell.barPosition === "right" ? width : 0)
                    y: rootShell.barPosition === "top" ? -height : (rootShell.barPosition === "bottom" ? height : 0)
                }
            },
            State {
                name: "shown"
                when: previewRoot.active
                PropertyChanges { target: animatedContainer; opacity: 1.0; x: 0; y: 0 }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"; to: "shown"
                ParallelAnimation {
                    NumberAnimation { properties: "x,y"; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { property: "opacity"; duration: 120; easing.type: Easing.OutQuad }
                }
            },
            Transition {
                from: "shown"; to: "hidden"
                ParallelAnimation {
                    NumberAnimation { properties: "x,y"; duration: 140; easing.type: Easing.InQuad }
                    NumberAnimation { property: "opacity"; duration: 100; easing.type: Easing.InQuad }
                }
            }
        ]

        Rectangle {
            anchors.fill: parent
            color: rootShell.colorBackground
            border.color: rootShell.colorBorder
            border.width: 2
            radius: 12
        }

        MouseArea { 
            anchors.fill: parent 
            hoverEnabled: true 
            acceptedButtons: Qt.NoButton
            onEntered: globalWorkspacePreview.cancelDismiss()
            onExited: globalWorkspacePreview.requestDismiss()
        }

        Text {
            id: titleLabel
            text: "Workspace " + previewRoot.targetWorkspace
            font.family: rootShell.shellFont
            font.pixelSize: 13
            font.bold: true
            color: rootShell.colorAccent
            x: 14; y: 10
        }

        RowLayout {
            x: titleLabel.x + titleLabel.implicitWidth + 24
            y: 12; height: titleLabel.implicitHeight; spacing: 8
            
            Repeater {
                model: viewportFrame.workspaceWindows
                delegate: Image {
                    visible: (modelData.class || "") !== "" && modelData.mapped
                    source: Quickshell.iconPath(getCleanIconName(modelData.class))
                    Layout.preferredWidth: 16; Layout.preferredHeight: 16
                    fillMode: Image.PreserveAspectFit
                }
            }
        }

        Rectangle {
            id: headerDivider
            width: parent.width - 28; height: 1
            color: rootShell.colorBorder
            x: 14; y: 30
        }

        Rectangle {
            id: viewportFrame
            x: 14; anchors.top: headerDivider.bottom; anchors.topMargin: 8
            anchors.bottom: parent.bottom; anchors.bottomMargin: 10
            color: Qt.rgba(0, 0, 0, 0.2); radius: 4; clip: true

            property var workspaceWindows: previewRoot.liveClientJson.filter(w => w.workspace.id === previewRoot.targetWorkspace)

            property var calculatedBounds: {
                if (!workspaceWindows || workspaceWindows.length === 0) {
                    return { "w": 1920, "h": 1080, "isVertical": false, "originX": 0, "originY": 0 };
                }
                let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                for (let i = 0; i < workspaceWindows.length; i++) {
                    let win = workspaceWindows[i];
                    if (!win.at || !win.size) continue;
                    if (win.at[0] < minX) minX = win.at[0];
                    if (win.at[1] < minY) minY = win.at[1];
                    if ((win.at[0] + win.size[0]) > maxX) maxX = win.at[0] + win.size[0];
                    if ((win.at[1] + win.size[1]) > maxY) maxY = win.at[1] + win.size[1];
                }
                let spanX = maxX - minX, spanY = maxY - minY;
                let verticalDetected = spanY > spanX;
                let normW = verticalDetected ? 1080 : 1920;
                let normH = verticalDetected ? 1920 : 1080;
                if (spanX > 0 && Math.abs(spanX - normW) > 100) normW = spanX;
                if (spanY > 0 && Math.abs(spanY - normH) > 100) normH = spanY;
                return { "w": normW, "h": normH, "isVertical": verticalDetected, "originX": minX, "originY": minY };
            }

            width: Math.round(height * (calculatedBounds.w / calculatedBounds.h))
            property real scaleX: width / calculatedBounds.w
            property real scaleY: height / calculatedBounds.h

            Repeater {
                model: viewportFrame.workspaceWindows
                delegate: Rectangle {
                    id: windowDelegate
                    x: ((modelData.at[0] - viewportFrame.calculatedBounds.originX) * viewportFrame.scaleX)
                    y: ((modelData.at[1] - viewportFrame.calculatedBounds.originY) * viewportFrame.scaleY)
                    width: Math.max(4, (modelData.size[0] * viewportFrame.scaleX))
                    height: Math.max(4, (modelData.size[1] * viewportFrame.scaleY))
                    visible: modelData.mapped
                    color: Qt.rgba(0, 0, 0, 0.6)
                    border.color: rootShell.colorBorder; border.width: 1; radius: 2; clip: true

                    property var wlToplevel: {
                        if (!modelData || !modelData.address) return null;
                        let targetAddr = modelData.address.trim().toLowerCase();
                        let match = Hyprland.toplevels.values.find(t => t.lastIpcObject && t.lastIpcObject.address && t.lastIpcObject.address.trim().toLowerCase() === targetAddr);
                        return match ? match.wayland : null;
                    }

                    Loader {
                        anchors.fill: parent
                        active: windowDelegate.wlToplevel !== null
                        sourceComponent: ScreencopyView {
                            captureSource: windowDelegate.wlToplevel
                            live: true; paintCursor: false
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                        height: Math.min(14, parent.height * 0.25)
                        color: "#cc11111b"
                        visible: parent.height > 20 && parent.width > 35; z: 10

                        Text {
                            text: (modelData.title && modelData.title.trim() !== "" && modelData.title !== "~") ? modelData.title : (modelData.class || "")
                            font.family: rootShell.shellFont; font.pixelSize: 8; font.bold: true; color: "#ffffff"
                            anchors.centerIn: parent; width: parent.width - 4; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: viewportFrame
            cursorShape: Qt.PointingHandCursor; z: 20; hoverEnabled: true
            propagateComposedEvents: true
            onPressed: (mouse) => mouse.accepted = true
            onReleased: (mouse) => mouse.accepted = true
            onClicked: {
                if (previewRoot.targetWorkspace !== -1) {
                    switchWorkspace.command = ["hyprctl", "dispatch", "workspace", previewRoot.targetWorkspace.toString()];
                    switchWorkspace.running = true;
                }
            }
        }
    }
}
