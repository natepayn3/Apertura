import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: launcherModuleRoot
    implicitWidth: 32
    implicitHeight: 32

    property var allApps: []
    property string activeSearchQuery: ""
    property bool menuOpen: false
    property bool windowAlive: false

    ListModel {
        id: dynamicAppModel
    }

    Component.onCompleted: {
        const localUri = Qt.resolvedUrl(".").toString();
        const basePath = localUri.replace("file://", "");
        
        appScanner.command = ["python3", basePath + "/get_apps.py"];
        appScanner.running = true;
    }

    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        rootScope.requestOpen(appLauncherModal);
        windowAlive = true;
        menuOpen = true;

        if (appScanner.command && appScanner.command.length > 1) {
            appScanner.running = false;
            appScanner.running = true;
        }
    }

    function closeMenu(): void {
        menuOpen = false;
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== appLauncherModal && menuOpen) {
                closeMenu();
            }
        }
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
        
        for (let i = 0; i < allApps.length; i++) {
            if (lowerQuery === "" || allApps[i].name.toLowerCase().indexOf(lowerQuery) !== -1) {
                dynamicAppModel.append({
                    name: allApps[i].name,
                    bin: allApps[i].bin,
                    iconPath: allApps[i].icon || ""
                });
            }
        }
        
        if (appListView.count > 0) {
            appListView.currentIndex = 0;
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

    Rectangle {
        id: triggerButton
        anchors.fill: parent
        color: launcherMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
        radius: 0 

        Text {
            anchors.centerIn: parent
            text: "󰣇" 
            font.family: "Rubik"
            font.pixelSize: 24
            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
        }

        MouseArea {
            id: launcherMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: appLauncherModal
        visible: launcherModuleRoot.windowAlive
        color: "transparent"
        
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && launcherModuleRoot.menuOpen) {
                activeSearchQuery = "";
                filterApps("");
                appListView.currentIndex = 0;
                appListView.keyboardActive = false; 
                globalTracker.lastWindowX = -1;
                globalTracker.lastWindowY = -1;
                globalTracker.isOverValidItem = false;
                appListView.positionViewAtBeginning();
                menuCard.forceActiveFocus();
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: closeMenu()
        }

        Rectangle {
            id: menuCard
            height: 300 
            
            // Drawer positioning anchors flush to the side panel
            x: 0
            anchors.top: parent.top
            anchors.topMargin: 12
            radius: 0
            color: "#9911111b" 
            border.width: 0
            clip: true
            focus: true

            states: [
                State {
                    name: "visible"
                    when: launcherModuleRoot.menuOpen
                    PropertyChanges { target: menuCard; width: 300; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: !launcherModuleRoot.menuOpen
                    PropertyChanges { target: menuCard; width: 0; opacity: 0.0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "visible"
                    ParallelAnimation {
                        NumberAnimation { property: "width"; duration: 250; easing.type: Easing.OutQuad }
                        NumberAnimation { property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { property: "width"; duration: 200; easing.type: Easing.InQuad }
                            NumberAnimation { property: "opacity"; duration: 200; easing.type: Easing.InQuad }
                        }
                        ScriptAction {
                            script: { launcherModuleRoot.windowAlive = false; }
                        }
                    }
                }
            ]

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_Down) {
                    appListView.keyboardActive = true; 
                    if (appListView.currentIndex < appListView.count - 1) {
                        appListView.currentIndex++;
                    }
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Up) {
                    appListView.keyboardActive = true; 
                    if (appListView.currentIndex > 0) {
                        appListView.currentIndex--;
                    }
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (appListView.currentIndex >= 0 && appListView.currentIndex < appListView.count) {
                        let targetApp = dynamicAppModel.get(appListView.currentIndex);
                        executeApplication(targetApp.bin);
                        closeMenu();
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
                    let windowPoint = globalTracker.mapToItem(appLauncherModal.contentItem, mouse.x, mouse.y);
                    
                    if (lastWindowX === -1) {
                        lastWindowX = windowPoint.x;
                        lastWindowY = windowPoint.y;
                        return;
                    }

                    if (windowPoint.x !== lastWindowX || windowPoint.y !== lastWindowY) {
                        lastWindowX = windowPoint.x;
                        lastWindowY = windowPoint.y;

                        appListView.keyboardActive = false; 

                        let listLocalPoint = appLauncherModal.contentItem.mapToItem(appListView, windowPoint.x, windowPoint.y);
                        let calculatedIndex = appListView.indexAt(listLocalPoint.x, listLocalPoint.y + appListView.contentY);

                        if (calculatedIndex !== -1) {
                            isOverValidItem = true;
                            if (calculatedIndex !== appListView.currentIndex) {
                                appListView.currentIndex = calculatedIndex;
                            }
                        } else {
                            isOverValidItem = false;
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: (mouse) => mouse.accepted = true
            }

            // Cross-fade layout wrapper container
            Item {
                id: textContentGroup
                anchors.fill: parent
                
                opacity: menuCard.width > 200 ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: activeSearchQuery === "" ? "Applications" : "Results for '" + activeSearchQuery + "'"
                        font.family: "Rubik"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                        color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                        Layout.alignment: Qt.AlignLeft
                        Layout.bottomMargin: 2
                        Layout.topMargin: 4
                    }

                    ListView {
                        id: appListView
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 2
                        model: dynamicAppModel
                        
                        property bool keyboardActive: false

                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: 60 
                        highlight: null

                        delegate: Item {
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
                                    width: 22; height: 22
                                    Layout.alignment: Qt.AlignVCenter

                                    Image {
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
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                z: 2 

                                onClicked: {
                                    appListView.currentIndex = index;
                                    executeApplication(model.bin);
                                    closeMenu();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
