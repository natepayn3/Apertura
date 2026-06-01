import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: workspaceContainer
    property bool isVertical: true
    property var theme
    implicitWidth: isVertical ? 28 : (layoutLoader.item ? layoutLoader.item.implicitWidth : 0)
    implicitHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight : 0) : 28

    property int activeWorkspace: 1
    property var activeWorkspaceList: [1, 2]
    property var occupiedMap: ({})

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
                        
                        if (!ids.includes(1)) ids.push(1);
                        if (!ids.includes(workspaceContainer.activeWorkspace)) ids.push(workspaceContainer.activeWorkspace);
                        
                        let maxId = Math.max(...ids, 0);
                        if (!ids.includes(maxId + 1)) ids.push(maxId + 1);
                        
                        for (let i = 1; i <= maxId + 1; i++) {
                            if (!ids.includes(i)) ids.push(i);
                        }

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
            property var theme: workspaceContainer.theme 
            property int wsId: modelData
            property bool isActive: workspaceContainer.activeWorkspace === wsId
            property bool isOccupied: workspaceContainer.occupiedMap[wsId] === true
            property bool isNewIndicatorSlot: index === (workspaceContainer.activeWorkspaceList.length - 1)

            implicitWidth: workspaceContainer.isVertical ? 28 : (isActive ? 58 : 28)
            implicitHeight: workspaceContainer.isVertical ? (isActive ? 58 : 28) : 28
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            onClicked: {
                workspaceContainer.activeWorkspace = wsId;
                switchWorkspace.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + wsId + "\" })"];
                switchWorkspace.running = true;
            }

            Process { id: switchWorkspace; running: false }

            Rectangle {
                id: hoverBackground
                width: workspaceContainer.isVertical ? 28 : (workspaceButton.isActive ? 58 : 28)
                height: workspaceContainer.isVertical ? (workspaceButton.isActive ? 58 : 28) : 28
                radius: 6
                anchors.centerIn: parent
                color: (workspaceButton.theme ? workspaceButton.theme.primary : "#89b4fa")
                opacity: workspaceButton.containsMouse ? 0.3 : 0.0
                z: 1
            }

            Rectangle {
                id: indicatorShape
                anchors.centerIn: parent
                width: workspaceContainer.isVertical ? (isActive ? 14 : 12) : (isActive ? 44 : 12)
                height: workspaceContainer.isVertical ? (isActive ? 44 : 12) : (isActive ? 14 : 12)
                radius: 6
                z: 2
                
                color: isActive ? (workspaceButton.theme ? workspaceButton.theme.primary : "#89b4fa") : (isOccupied ? (workspaceButton.theme ? workspaceButton.theme.text : "#cdd6f4") : "transparent")
                border.width: (!isActive && !isOccupied) ? 1.5 : 0
                border.color: (!isActive && !isOccupied) ? (workspaceButton.theme ? workspaceButton.theme.outline : "#b3ffffff") : "transparent"

                Text {
                    text: workspaceButton.wsId.toString()
                    font.family: "Rubik"; font.pixelSize: 11; font.bold: true
                    color: workspaceButton.isActive ? (workspaceButton.theme ? workspaceButton.theme.onPrimary : "#11111b") : (workspaceButton.theme ? workspaceButton.theme.text : "#cdd6f4")
                    anchors.fill: parent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    opacity: workspaceButton.isActive ? 1.0 : 0.0
                }
            }
        }
    }
}
