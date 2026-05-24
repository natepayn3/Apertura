import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: workspaceContainer
    
    // 🎛️ ORIENTATION TOGGLE
    property bool isVertical: true

    // 🔒 FIXED: Read sizes dynamically out of the active instantiated loader item context instead of a broken component ID
    implicitWidth: isVertical ? 22 : (layoutLoader.item ? layoutLoader.item.implicitWidth : 0)
    implicitHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight : 0) : 22

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
    // 🎨 DYNAMIC LAYOUT CELL FRAMEWORK
    // ==========================================
    Loader {
        id: layoutLoader
        anchors.fill: parent
        sourceComponent: workspaceContainer.isVertical ? verticalLayoutComponent : horizontalLayoutComponent
    }

    // 🔄 VERTICAL ORIENTATION (Column Layout Engine)
    Component {
        id: verticalLayoutComponent
        ColumnLayout {
            anchors.fill: parent
            spacing: 10
            
            Repeater {
                model: workspaceContainer.activeWorkspaceList
                delegate: workspaceButtonDelegate
            }
        }
    }

    // ↔️ HORIZONTAL ORIENTATION (Original Row Layout Engine)
    Component {
        id: horizontalLayoutComponent
        RowLayout {
            anchors.fill: parent
            spacing: 10
            
            Repeater {
                model: workspaceContainer.activeWorkspaceList
                delegate: workspaceButtonDelegate
            }
        }
    }

    // ==========================================
    // 🪴 CELL REPEATER DELEGATE TEMPLATE
    // ==========================================
    Component {
        id: workspaceButtonDelegate
        
        MouseArea {
            id: workspaceButton
            property int wsId: modelData
            property bool isActive: workspaceContainer.activeWorkspace === wsId
            property bool isOccupied: workspaceContainer.occupiedMap[wsId] === true

            implicitWidth: workspaceContainer.isVertical ? 22 : (isActive ? 50 : 30)
            implicitHeight: workspaceContainer.isVertical ? (isActive ? 50 : 30) : 22
            cursorShape: Qt.PointingHandCursor

            Behavior on implicitWidth {
                enabled: !workspaceContainer.isVertical
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }
            Behavior on implicitHeight {
                enabled: workspaceContainer.isVertical
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
            }

            onClicked: {
                workspaceContainer.activeWorkspace = wsId;
                switchWorkspace.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + wsId + "\" })"];
                switchWorkspace.running = true;
            }

            Process { id: switchWorkspace; running: false }

            Rectangle {
                anchors.fill: parent
                radius: workspaceContainer.isVertical ? width / 2 : height / 2
                
                // 🎨 TRANSPARENT DOTS STYLE: Only fill the active workspace circle. All others are transparent wireframes.
                color: isActive ? "#cdd6f4" : "transparent"
                
                border.width: 1
                // 🎨 WIREFRAME OUTLINE HIERARCHY: Active solid capsule, occupied has clear prominence, placeholder is a lighter ghost ring.
                border.color: isActive   ? "#cdd6f4" : 
                              isOccupied ? "#b4befe" : "#6c7086"

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Text {
                    text: workspaceButton.wsId.toString()
                    font.family: "Rubik"
                    font.pixelSize: 12
                    font.bold: true
                    color: workspaceButton.isActive ? "#11111b" : (workspaceButton.isOccupied ? "#b4befe" : "#6c7086")
                    
                    width: parent.width
                    height: parent.height
                    
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    // Show text for active/occupied, keep it completely transparent for empty new workspace slots
                    opacity: (workspaceButton.isActive || workspaceButton.isOccupied) ? 1.0 : 0.0

                    Behavior on opacity { NumberAnimation { duration: 100 } }
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
            }
        }
    }
}
