import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

RowLayout {
    id: workspaceContainer
    spacing: 12

    property int activeWorkspace: 1
    property var activeWorkspaceList: [1, 2]
    
    // Tracks which workspace IDs actually contain open windows
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
                        json.forEach(ws => {
                            if (ws.windows > 0) {
                                occupied[ws.id] = true;
                            }
                        });
                        workspaceContainer.occupiedMap = occupied;
                        
                        if (!ids.includes(workspaceContainer.activeWorkspace)) {
                            ids.push(workspaceContainer.activeWorkspace);
                        }
                        
                        let maxId = Math.max(...ids, 0);
                        if (!ids.includes(maxId + 1)) {
                            ids.push(maxId + 1);
                        }
                        
                        ids.sort((a, b) => a - b);
                        workspaceContainer.activeWorkspaceList = ids;
                    }
                } catch (e) {
                    console.log("workspace list parse error:", e);
                }
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
                } catch (e) {
                    console.log("active workspace parse error:", e);
                }
            }
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            queryActiveWorkspace.running = false;
            queryActiveWorkspace.running = true;
            queryWorkspaceList.running = false;
            queryWorkspaceList.running = true;
        }
    }

    Repeater {
        model: workspaceContainer.activeWorkspaceList

        delegate: MouseArea {
            id: workspaceButton
            property int wsId: modelData
            property bool isActive: workspaceContainer.activeWorkspace === wsId
            property bool isOccupied: workspaceContainer.occupiedMap[wsId] === true

            implicitWidth: isActive ? 40 : 20
            implicitHeight: 18
            cursorShape: Qt.PointingHandCursor

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.InOutQuad
                }
            }

            onClicked: {
                workspaceContainer.activeWorkspace = wsId;

                switchWorkspace.command = [
                    "hyprctl",
                    "dispatch",
                    "hl.dsp.focus({ workspace = \"" + wsId + "\" })"
                ];
                switchWorkspace.running = true;
            }

            Process {
                id: switchWorkspace
                running: false
                stdout: StdioCollector { onTextChanged: { if (text.trim().length > 0) console.log("hyprctl:", text); } }
                stderr: StdioCollector { onTextChanged: { if (text.trim().length > 0) console.log("hyprctl error:", text); } }
            }

            Rectangle {
                anchors.fill: parent
                radius: 10
                
                // 👇 UPDATED: Lifted color profiles to stay crisp against #9911111b glass transparency
                color: isActive   ? '#afbaff' :         // Active pill remains your standard accent
                       isOccupied ? "#45475a" : "transparent" // Occupied gets Surface1; Empty is cleanly punched out
                
                border.width: 2
                border.color: isActive   ? '#afbaff' : 
                              isOccupied ? "#a6adc8" : "#585b70" // Subtle contrast adjustments for the sub-states
            }
        }
    }
}