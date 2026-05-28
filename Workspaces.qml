import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: workspaceContainer
    
    // 🎛️ ORIENTATION TOGGLE
    property bool isVertical: true

    implicitWidth: isVertical ? 24 : (layoutLoader.item ? layoutLoader.item.implicitWidth : 0)
    implicitHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight : 0) : 24

    property int activeWorkspace: 1
    property var activeWorkspaceList: [1, 2]
    property var occupiedMap: ({})

    // 🔄 HYPRLAND POLLING LOGIC
    Process {
        id: queryWorkspaceList
        command: ["hyprctl", "workspaces", "-j"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    const cleaned = text.trim();
                    if (cleaned.length === 0) return;
                    const json = JSON.parse(cleaned);
                    if (Array.isArray(json)) {
                        let ids = json.map(ws => ws.id).filter(id => id > 0);
                        let occupied = {};
                        json.forEach(ws => { if (ws.windows > 0) occupied[ws.id] = true; });
                        workspaceContainer.occupiedMap = occupied;
                        if (!ids.includes(workspaceContainer.activeWorkspace)) ids.push(workspaceContainer.activeWorkspace);
                        let maxId = Math.max(...ids, 0);
                        if (!ids.includes(maxId + 1)) ids.push(maxId + 1);
                        ids.sort((a, b) => a - b);
                        workspaceContainer.activeWorkspaceList = ids;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: queryActiveWorkspace
        command: ["hyprctl", "activeworkspace", "-j"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    const cleaned = text.trim();
                    if (cleaned.length === 0) return;
                    const json = JSON.parse(cleaned);
                    if (json && json.id !== undefined) {
                        workspaceContainer.activeWorkspace = json.id;
                        queryWorkspaceList.running = false;
                        queryWorkspaceList.running = true;
                    }
                } catch (e) {}
            }
        }
    }

    Timer { interval: 100; running: true; repeat: true; onTriggered: { queryActiveWorkspace.running = false; queryActiveWorkspace.running = true; queryWorkspaceList.running = false; queryWorkspaceList.running = true; } }

    Loader {
        id: layoutLoader
        anchors.fill: parent
        sourceComponent: workspaceContainer.isVertical ? verticalLayoutComponent : horizontalLayoutComponent
    }

    Component {
        id: verticalLayoutComponent
        ColumnLayout { anchors.fill: parent; spacing: 10; Repeater { model: workspaceContainer.activeWorkspaceList; delegate: workspaceButtonDelegate } }
    }

    Component {
        id: horizontalLayoutComponent
        RowLayout { anchors.fill: parent; spacing: 10; Repeater { model: workspaceContainer.activeWorkspaceList; delegate: workspaceButtonDelegate } }
    }

    Component {
        id: workspaceButtonDelegate
        
        MouseArea {
            id: workspaceButton
            property int wsId: modelData
            property bool isActive: workspaceContainer.activeWorkspace === wsId
            property bool isOccupied: workspaceContainer.occupiedMap[wsId] === true
            property bool isNewIndicatorSlot: index === (workspaceContainer.activeWorkspaceList.length - 1)

            implicitWidth: workspaceContainer.isVertical ? 24 : (isActive ? 44 : 24)
            implicitHeight: workspaceContainer.isVertical ? (isActive ? 44 : 24) : 24
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onEntered: {
                if (isNewIndicatorSlot) return;
                if (typeof mainBarWindow !== "undefined" && mainBarWindow.previewHandle) {
                    mainBarWindow.previewHandle.workspaceId = wsId;
                    mainBarWindow.previewHandle.active = true;
                }
            }

            onExited: {
                if (typeof mainBarWindow !== "undefined" && mainBarWindow.previewHandle) {
                    mainBarWindow.previewHandle.active = false;
                }
            }

            onClicked: {
                workspaceContainer.activeWorkspace = wsId;
                switchWorkspace.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + wsId + "\" })"];
                switchWorkspace.running = true;
            }

            Process { id: switchWorkspace; running: false }

            Rectangle {
                anchors.centerIn: parent
                width: workspaceContainer.isVertical ? (isActive ? 14 : 12) : (isActive ? 44 : 12)
                height: workspaceContainer.isVertical ? (isActive ? 44 : 12) : (isActive ? 14 : 12)
                radius: 6
                color: isActive ? "#ffffff" : (isNewIndicatorSlot ? "transparent" : (isOccupied ? "#ffffff" : "#1affffff"))
                border.width: (isNewIndicatorSlot && !isActive) ? 1.5 : 0
                border.color: (isNewIndicatorSlot && !isActive) ? "#ffffff" : "transparent"

                Text {
                    text: workspaceButton.wsId.toString()
                    font.family: "Rubik"; font.pixelSize: 11; font.bold: true; color: "#11111b"
                    anchors.fill: parent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    opacity: workspaceButton.isActive ? 1.0 : 0.0
                }
            }
        }
    }
}
