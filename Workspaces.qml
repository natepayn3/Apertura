import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: workspaceContainer
    
    // Explicit bounding envelope so the absolute tracking layer works safely
    implicitWidth: mainRowLayout.implicitWidth
    implicitHeight: 22

    property int activeWorkspace: 1
    property var activeWorkspaceList: [1, 2]
    property var occupiedMap: ({})

    // 🔄 REUSE POLLING LOGIC EXECUTIONS UNCHANGED
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
                            if (ws.windows > 0) occupied[ws.id] = true;
                        });
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

    Timer {
        interval: 100; running: true; repeat: true
        onTriggered: {
            queryActiveWorkspace.running = false; queryActiveWorkspace.running = true;
            queryWorkspaceList.running = false; queryWorkspaceList.running = true;
        }
    }

    // ==========================================
    // 🎨 CORE VISUAL ROW INTERFACE
    // ==========================================
    RowLayout {
        id: mainRowLayout
        anchors.fill: parent
        spacing: 10

        Repeater {
            id: workspaceRepeater
            model: workspaceContainer.activeWorkspaceList

            delegate: MouseArea {
                id: workspaceButton
                property int wsId: modelData
                property bool isActive: workspaceContainer.activeWorkspace === wsId
                property bool isOccupied: workspaceContainer.occupiedMap[wsId] === true

                // Stretches smoothly to make room for text index injections
                implicitWidth: isActive ? 35 : (isOccupied ? 24 : 20)
                implicitHeight: 20
                cursorShape: Qt.PointingHandCursor

                Behavior on implicitWidth {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                onClicked: {
                    workspaceContainer.activeWorkspace = wsId;
                    switchWorkspace.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + wsId + "\" })"];
                    switchWorkspace.running = true;
                }

                Process { id: switchWorkspace; running: false }

                // Underlying cell shell
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    
                    // Fades background alpha away if empty to leave just a clean border
                    color: isActive   ? "#cdd6f4" : 
                           isOccupied ? "#313244" : "transparent"
                    
                    border.width: 2
                    border.color: isActive   ? "#cdd6f4" : 
                                  isOccupied ? "#a6adc8" : "#45475a"

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    // 🎯 INDEX NUMERIC TEXT REVEAL: Fades into view when expanded
                    Text {
                        text: workspaceButton.wsId.toString()
                        font.family: "Rubik"
                        font.pixelSize: 12
                        font.bold: true
                        color: "#11111b" // Contrast dark glyph color against bright active pill
                        
                        // 🎯 MANUAL BOUNDING PROFILE MATRIX
                        // Corrects both baseline drop drop-shifts and subpixel tracking horizontal drift
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 1
                        anchors.horizontalCenterOffset: -1
                        
                        opacity: workspaceButton.isActive ? 1.0 : 0.0
                        scale: workspaceButton.isActive ? 1.0 : 0.5

                        Behavior on opacity { NumberAnimation { duration: 100 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                    }
                }
            }
        }
    }
}
