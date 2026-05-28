import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: workspaceContainer
    
    // 🎛️ ORIENTATION TOGGLE
    property bool isVertical: true

    // Dynamically tracks geometry metrics from the active orientation loader item
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
    // 🪴 DOT/PILL CELL DELEGATE TEMPLATE
    // ==========================================
    Component {
        id: workspaceButtonDelegate
        
        MouseArea {
            id: workspaceButton
            property int wsId: modelData
            property bool isActive: workspaceContainer.activeWorkspace === wsId
            property bool isOccupied: workspaceContainer.occupiedMap[wsId] === true
            
            // New dot tracker checks if this item sits at the end of the calculated workspace array
            property bool isNewIndicatorSlot: index === (workspaceContainer.activeWorkspaceList.length - 1)

            // Large, easy-to-click hitboxes
            implicitWidth: workspaceContainer.isVertical ? 24 : (isActive ? 44 : 24)
            implicitHeight: workspaceContainer.isVertical ? (isActive ? 44 : 24) : 24
            cursorShape: Qt.PointingHandCursor

            Behavior on implicitWidth {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }
            Behavior on implicitHeight {
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            // Preserved original Lua dispatcher syntax
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

                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                
                // 🎯 THE FIX: Evaluates to "transparent" if it's the empty placeholder node, otherwise fills properly
                color: isActive           ? "#a6e3a1" : 
                       isNewIndicatorSlot ? "transparent" : 
                       isOccupied         ? "#cdd6f4" : "#45475a"
                
                // Enforces a solid, clean text-colored boundary stroke to compose the hollow ring shape
                border.width: (isNewIndicatorSlot && !isActive) ? 1.5 : 0
                border.color: (isNewIndicatorSlot && !isActive) ? "#cdd6f4" : "transparent"

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on border.color { ColorAnimation { duration: 140 } }

                Text {
                    text: workspaceButton.wsId.toString()
                    font.family: "Rubik"
                    font.pixelSize: 11
                    font.bold: true
                    color: "#11111b"
                    
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    
                    opacity: workspaceButton.isActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }
        }
    }
}
