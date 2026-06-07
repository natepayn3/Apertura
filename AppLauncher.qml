import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Item {
    id: launcherModuleRoot
    implicitWidth: 32
    implicitHeight: 32

    property var allApps: []
    property string activeSearchQuery: ""

    readonly property int typeHeader: 0
    readonly property int typeAppItem: 1

    readonly property string cachePath: Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json"

    ListModel {
        id: dynamicAppModel
    }

    Component.onCompleted: {
        const localUri = Qt.resolvedUrl(".").toString();
        const basePath = localUri.replace("file://", "");
        
        appScanner.command = ["python3", basePath + "/Scripts/get_apps.py"];
        appScanner.running = true;
    }

    function toggleMenu(): void {
        drawerTemplate.isOpen = !drawerTemplate.isOpen;
        if (drawerTemplate.isOpen) {
            activeSearchQuery = "";
            filterApps("");
        }
    }

    function togglePin(binString) {
        let currentPins = (rootScope.sharedPinnedApps || []).slice(); 
        let index = currentPins.indexOf(binString);
        
        if (index !== -1) {
            currentPins.splice(index, 1);
        } else {
            currentPins.push(binString);
        }
        
        let payload = { "pins": currentPins };
        let jsonString = JSON.stringify(payload);
        
        Quickshell.execDetached(["sh", "-c", "mkdir -p $(dirname " + cachePath + ") && echo '" + jsonString.replace(/'/g, "'\\''") + "' > " + cachePath]);
        rootScope.sharedPinnedApps = currentPins;
    }

    function executeApplication(binString) {
        let cleanBin = binString.trim();
        
        if (cleanBin.endsWith(".desktop")) {
            let filename = cleanBin.substring(cleanBin.lastIndexOf('/') + 1);
            Quickshell.execDetached(["gtk-launch", filename]);
            return;
        }

        let argsArray = [];
        let currentToken = "";
        let inQuotes = false;
        let quoteChar = "";

        for (let i = 0; i < cleanBin.length; i++) {
            let char = cleanBin.charAt(i);

            if ((char === '"' || char === "'") && (i === 0 || cleanBin.charAt(i - 1) !== '\\')) {
                if (inQuotes && char === quoteChar) {
                    inQuotes = false;
                } else if (!inQuotes) {
                    inQuotes = true;
                    quoteChar = char;
                }
            } else if (char === ' ' && !inQuotes) {
                if (currentToken.length > 0) {
                    argsArray.push(currentToken);
                    currentToken = "";
                }
            } else {
                currentToken += char;
            }
        }
        if (currentToken.length > 0) {
            argsArray.push(currentToken);
        }

        if (argsArray.length > 0) {
            Quickshell.execDetached(argsArray);
        }
    }

    function filterApps(query) {
        dynamicAppModel.clear();
        let lowerQuery = query.toLowerCase().trim();
        let currentPins = rootScope.sharedPinnedApps || [];
        
        let pinnedItems = [];
        let normalItems = [];

        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i];
            
            if (lowerQuery !== "" && app.name.toLowerCase().indexOf(lowerQuery) === -1) {
                continue;
            }

            let isPinned = currentPins.indexOf(app.bin) !== -1;

            let basePayload = {
                itemType: typeAppItem,
                name: app.name,
                bin: app.bin,
                iconPath: app.icon || "",
                isPinned: isPinned
            };

            let normalPayload = Object.assign({}, basePayload, { listSource: "normal" });
            normalItems.push(normalPayload);

            if (isPinned) {
                let pinnedPayload = Object.assign({}, basePayload, { listSource: "pinned" });
                pinnedItems.push(pinnedPayload);
            }
        }

        if (lowerQuery === "") {
            if (pinnedItems.length > 0) {
                dynamicAppModel.append({ itemType: typeHeader, name: "Pinned", bin: "" });
                pinnedItems.forEach(function(item) { dynamicAppModel.append(item); });
            }
            
            if (normalItems.length > 0) {
                dynamicAppModel.append({ itemType: typeHeader, name: "Applications", bin: "" });
                normalItems.forEach(function(item) { dynamicAppModel.append(item); });
            }
        } else {
            if (normalItems.length > 0) {
                dynamicAppModel.append({ itemType: typeHeader, name: "Results for '" + query + "'", bin: "" });
                normalItems.forEach(function(item) { dynamicAppModel.append(item); });
            }
        }
        
        if (appListView.count > 0) {
            for (let j = 0; j < dynamicAppModel.count; j++) {
                if (dynamicAppModel.get(j).itemType === typeAppItem) {
                    appListView.currentIndex = j;
                    break;
                }
            }
        }
    }

    Process {
        id: appScanner
        command: ["true"]
        running: false

        stdout: StdioCollector {
            onTextChanged: {
                let cleanText = text.trim();
                if (!cleanText || cleanText === "[]") return;

                try {
                    allApps = JSON.parse(cleanText);
                    filterApps(activeSearchQuery);
                } catch(e) {}
            }
        }
    }

    Connections {
        target: rootScope
        
        function onActiveModalChanged() {
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                drawerTemplate.isOpen = false;
            }
        }

        function onSharedPinnedAppsChanged() {
            filterApps(activeSearchQuery);
        }
    }

    Rectangle {
        id: triggerButton
        anchors.fill: parent
        radius: 0 
        color: "transparent"

        Image {
            id: launcherLogo
            anchors.centerIn: parent
            source: "file://" + Qt.resolvedUrl(".").toString().replace("file://", "") + "/Assets/logo.png"
            sourceSize.width: 24
            sourceSize.height: 24
            fillMode: Image.PreserveAspectFit
            visible: false 
        }

        ColorOverlay {
            anchors.fill: launcherLogo
            source: launcherLogo
            color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff"
        }

        Rectangle {
            id: hoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: launcherMouseArea.containsMouse ? 0.3 : 0.0
            z: 1 
        }

        MouseArea {
            id: launcherMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 300
        modalToken: "launcher"
        anchorTop: true

        onIsOpenChanged: {
            if (isOpen) {
                activeSearchQuery = "";
                filterApps("");
                appListView.keyboardActive = false; 
                globalTracker.lastWindowX = -1;
                globalTracker.lastWindowY = -1;
                globalTracker.isOverValidItem = false;
                appListView.positionViewAtBeginning();
                mainLayoutContainer.forceActiveFocus();
            }
        }

        MouseArea {
            id: globalTracker
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton 
            z: 10 

            property int lastWindowX: -1
            property int lastWindowY: -1
            
            property bool isOverValidItem: false
            cursorShape: isOverValidItem ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPositionChanged: (mouse) => {
                let windowPoint = globalTracker.mapToItem(drawerTemplate.contentItem, mouse.x, mouse.y);
                
                if (lastWindowX === -1) {
                    lastWindowX = windowPoint.x;
                    lastWindowY = windowPoint.y;
                    return;
                }

                if (windowPoint.x !== lastWindowX || windowPoint.y !== lastWindowY) {
                    lastWindowX = windowPoint.x;
                    lastWindowY = windowPoint.y;

                    appListView.keyboardActive = false; 

                    let listLocalPoint = drawerTemplate.contentItem.mapToItem(appListView, windowPoint.x, windowPoint.y);
                    let calculatedIndex = appListView.indexAt(listLocalPoint.x, listLocalPoint.y + appListView.contentY);

                    if (calculatedIndex !== -1) {
                        let itemData = dynamicAppModel.get(calculatedIndex);
                        if (itemData && itemData.itemType === typeAppItem) {
                            isOverValidItem = true;
                            if (calculatedIndex !== appListView.currentIndex) {
                                appListView.currentIndex = calculatedIndex;
                            }
                            return;
                        }
                    }
                    isOverValidItem = false;
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onPressed: (mouse) => mouse.accepted = true
        }

        ColumnLayout {
            id: mainLayoutContainer
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    drawerTemplate.isOpen = false;
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_Down) {
                    appListView.keyboardActive = true; 
                    for (let i = appListView.currentIndex + 1; i < appListView.count; i++) {
                        if (dynamicAppModel.get(i).itemType === typeAppItem) {
                            appListView.currentIndex = i;
                            break;
                        }
                    }
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Up) {
                    appListView.keyboardActive = true; 
                    for (let i = appListView.currentIndex - 1; i >= 0; i--) {
                        if (dynamicAppModel.get(i).itemType === typeAppItem) {
                            appListView.currentIndex = i;
                            break;
                        }
                    }
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    let currentData = dynamicAppModel.get(appListView.currentIndex);
                    if (currentData && currentData.itemType === typeAppItem) {
                        executeApplication(currentData.bin);
                        drawerTemplate.isOpen = false;
                    }
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_Backspace) {
                    if (activeSearchQuery.length > 0) {
                        activeSearchQuery = activeSearchQuery.slice(0, -1);
                        filterApps(activeSearchQuery);
                    }
                    event.accepted = true;
                } 
                else if (event.text.length > 0 && event.text.match(/[\w\s.-]/)) {
                    activeSearchQuery += event.text;
                    filterApps(activeSearchQuery);
                    event.accepted = true;
                }
            }

            ListView {
                id: appListView
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 2
                model: dynamicAppModel
                
                property bool keyboardActive: false

                highlightFollowsCurrentItem: true
                highlightMoveDuration: 60 
                highlight: null

                delegate: DelegateChooser {
                    role: "itemType"

                    DelegateChoice {
                        roleValue: typeHeader
                        Item {
                            width: appListView.width
                            height: 34
                            Text {
                                text: model.name
                                font.family: "Rubik"
                                font.pixelSize: 18
                                font.weight: Font.Bold
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 2
                                anchors.bottomMargin: 2
                            }
                        }
                    }

                    DelegateChoice {
                        roleValue: typeAppItem
                        Item {
                            id: delegateRoot
                            width: appListView.width; height: 36

                            Rectangle {
                                anchors.fill: parent
                                color: (appListView.currentIndex === index) ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
                                radius: 0 
                                z: 0 
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10; anchors.rightMargin: 10
                                spacing: 12
                                z: 1

                                Item {
                                    id: appIconContainer
                                    width: 22; height: 22
                                    Layout.alignment: Qt.AlignVCenter

                                    Image {
                                        id: rawAppIcon
                                        anchors.fill: parent
                                        sourceSize.width: 22; sourceSize.height: 22
                                        visible: model.iconPath !== "" 
                                        source: model.iconPath ? "file://" + model.iconPath : ""
                                        fillMode: Image.PreserveAspectFit
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 0 
                                        color: rootScope.theme ? rootScope.theme.theme_outline : "#1affffff" 
                                        visible: model.iconPath === ""

                                        Text {
                                            anchors.centerIn: parent
                                            text: model.name.charAt(0).toUpperCase()
                                            font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold
                                            color: (appListView.currentIndex === index) ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") 
                                        }
                                    }
                                }

                                Text {
                                    text: model.name
                                    font.family: "Rubik"; font.weight: Font.Medium; font.pixelSize: 14
                                    color: (appListView.currentIndex === index) ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") 
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight 
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: "push_pin"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    color: (appListView.currentIndex === index) ? 
                                        (rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa") : 
                                        (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff")
                                    visible: model.isPinned
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.rightMargin: 4
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                z: 2 

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        togglePin(model.bin);
                                    } else {
                                        appListView.currentIndex = index;
                                        executeApplication(model.bin);
                                        drawerTemplate.isOpen = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
