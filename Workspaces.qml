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

    property bool isSpecialOccupied: false
    property bool isSpecialActive: false

    Process {
        id: queryWorkspaceList
        command: ["hyprctl", "workspaces", "-j"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    const cleaned = text.trim();
                    if (!cleaned) return;
                    const json = JSON.parse(cleaned);
                    if (Array.isArray(json)) {
                        let ids = json.map(ws => ws.id).filter(id => id > 0);
                        let occupied = {};
                        let specialHasWindows = false;

                        json.forEach(ws => { 
                            if (ws.windows > 0) {
                                if (ws.id > 0) {
                                    occupied[ws.id] = true;
                                } else if (ws.name.startsWith("special") || ws.id < 0) {
                                    specialHasWindows = true;
                                }
                            }
                        });
                        
                        workspaceContainer.occupiedMap = occupied;
                        workspaceContainer.isSpecialOccupied = specialHasWindows;

                        if (!ids.includes(1)) ids.push(1);
                        if (!ids.includes(workspaceContainer.activeWorkspace)) ids.push(workspaceContainer.activeWorkspace);

                        let maxId = Math.max(...ids, 0);
                        if (!ids.includes(maxId + 1)) ids.push(maxId + 1);

                        for (let i = 1; i <= maxId + 1; i++) {
                            if (!ids.includes(i)) ids.push(i);
                        }

                        ids.sort((a, b) => a - b);
                        
                        if (workspaceContainer.isSpecialOccupied || workspaceContainer.isSpecialActive) {
                            if (!ids.includes(-99)) ids.push(-99);
                        }
                        
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
                    if (!cleaned) return;
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

    Process {
        id: querySpecialMonitorState
        command: ["hyprctl", "monitors", "-j"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    const cleaned = text.trim();
                    if (!cleaned) return;
                    const json = JSON.parse(cleaned);
                    if (Array.isArray(json)) {
                        let foundActive = false;
                        for (let i = 0; i < json.length; i++) {
                            if (json[i].focused === true) {
                                if (json[i].specialWorkspace && json[i].specialWorkspace.id !== 0) {
                                    foundActive = true;
                                }
                                break;
                            }
                        }
                        workspaceContainer.isSpecialActive = foundActive;
                    }
                } catch (e) {}
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
            querySpecialMonitorState.running = false;
            querySpecialMonitorState.running = true;
        }
    }

    Flickable {
        id: scrollContainer
        anchors.fill: parent
        contentWidth: isVertical ? parent.width : (layoutLoader.item ? layoutLoader.item.implicitWidth : parent.width)
        contentHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight : parent.height) : parent.height
        flickableDirection: isVertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Loader {
            id: layoutLoader
            width: isVertical ? parent.width : implicitWidth
            height: isVertical ? implicitHeight : parent.height
            sourceComponent: workspaceContainer.isVertical ? verticalLayoutComponent : horizontalLayoutComponent
        }
    }

    Connections {
        target: workspaceContainer
        function onThemeChanged() {
            layoutLoader.sourceComponent = workspaceContainer.isVertical
                ? verticalLayoutComponent
                : horizontalLayoutComponent
        }
    }

    Component {
        id: verticalLayoutComponent
        ColumnLayout {
            spacing: 10
            Repeater {
                model: workspaceContainer.activeWorkspaceList
                delegate: workspaceButtonDelegate
            }
        }
    }

    Component {
        id: horizontalLayoutComponent
        RowLayout {
            spacing: 10
            Repeater {
                model: workspaceContainer.activeWorkspaceList
                delegate: workspaceButtonDelegate
            }
        }
    }

    Component {
        id: workspaceButtonDelegate
        MouseArea {
            id: workspaceButton
            property int wsId: modelData
            property bool isSpecialNode: wsId === -99
            property bool isActive: isSpecialNode ? workspaceContainer.isSpecialActive : (workspaceContainer.activeWorkspace === wsId && !workspaceContainer.isSpecialActive)
            property bool isOccupied: isSpecialNode ? workspaceContainer.isSpecialOccupied : workspaceContainer.occupiedMap[wsId] === true
            property bool isNewIndicatorSlot: index === (workspaceContainer.activeWorkspaceList.length - 1)

            property int targetWidth: isSpecialNode ? 28 : (workspaceContainer.isVertical ? 28 : (isActive ? 58 : 28))
            property int targetHeight: isSpecialNode ? 28 : (workspaceContainer.isVertical ? (isActive ? 58 : 28) : 28)

            implicitWidth: targetWidth
            implicitHeight: targetHeight
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true

            Behavior on targetWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on targetHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            onEntered: {
                if (isSpecialNode) return;
                if (typeof mainBarWindow !== "undefined" && mainBarWindow.previewPopup && isOccupied) {
                    let globalCoords = workspaceButton.mapToItem(null, 0, 0);
                    let popup = mainBarWindow.previewPopup;
                    if (popup) {
                        popup.cancelDismiss();
                        popup.screen = mainBarWindow.screen;
                        popup.marginLeft = mainBarWindow.x + mainBarWindow.width + 13;
                        popup.marginTop = globalCoords.y - (200 / 2) + (workspaceButton.height / 2);
                        
                        Qt.callLater(function() {
                            if (popup) popup.targetWorkspace = wsId;
                        });
                    }
                }
            }

            onExited: {
                if (typeof mainBarWindow !== "undefined" && mainBarWindow.previewPopup) {
                    mainBarWindow.previewPopup.requestDismiss();
                }
            }

            onClicked: {
                if (isSpecialNode) {
                    switchWorkspace.command = ["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special(\"magic\")"];
                } else {
                    switchWorkspace.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + wsId + "\" })"];
                }
                switchWorkspace.running = true;
            }

            Process { id: switchWorkspace; running: false }

            Rectangle {
                id: hoverBackground
                width: parent.width
                height: parent.height
                radius: height / 2
                anchors.centerIn: parent
                color: workspaceContainer.theme ? workspaceContainer.theme.theme_primary : "#89b4fa"
                opacity: workspaceButton.containsMouse ? 0.3 : 0.0
                z: 1
            }

            Rectangle {
                id: indicatorShape
                anchors.centerIn: parent
                visible: !isSpecialNode
                
                property int shapeWidth: workspaceContainer.isVertical ? (workspaceButton.isActive ? 14 : 12) : (workspaceButton.isActive ? 44 : 12)
                property int shapeHeight: workspaceContainer.isVertical ? (workspaceButton.isActive ? 44 : 12) : (workspaceButton.isActive ? 14 : 12)
                
                width: shapeWidth
                height: shapeHeight
                radius: height / 2
                z: 2

                Behavior on shapeWidth { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on shapeHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                color: {
                    if (!workspaceContainer.theme) return "transparent";
                    if (workspaceButton.isActive) return workspaceContainer.theme.theme_primary;
                    if (workspaceButton.isOccupied) return workspaceContainer.theme.theme_fg;
                    return "transparent";
                }

                border.width: (!workspaceButton.isActive && !workspaceButton.isOccupied) ? 1.5 : 0
                border.color: {
                    if (!workspaceContainer.theme) return "transparent";
                    return (!workspaceButton.isActive && !workspaceButton.isOccupied)
                        ? workspaceContainer.theme.theme_outline
                        : "transparent";
                }

                Text {
                    text: wsId.toString()
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: "Rubik"
                    font.pixelSize: 11
                    font.bold: true
                    
                    color: {
                        if (!workspaceContainer.theme) return "#ffffff";
                        return workspaceButton.isActive
                            ? workspaceContainer.theme.theme_onPrimary
                            : workspaceContainer.theme.theme_fg;
                    }
                    opacity: workspaceButton.isActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }

            Text {
                id: specialIconLayer
                visible: isSpecialNode
                anchors.centerIn: parent
                text: "star"
                
                font.family: "Material Symbols Outlined"
                font.pixelSize: 16
                font.bold: true
                z: 2
                
                font.letterSpacing: workspaceButton.isActive ? 0.01 : 0.0
                
                color: {
                    if (!workspaceContainer.theme) return workspaceButton.isActive ? "#f5c2e7" : "#ffffff";
                    return workspaceButton.isActive 
                        ? workspaceContainer.theme.theme_primary 
                        : workspaceContainer.theme.theme_fg;
                }
            }
        }
    }
}
