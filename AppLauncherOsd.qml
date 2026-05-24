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
    
    // Controls actual PanelWindow visibility
    property bool menuOpen: false

    ListModel {
        id: dynamicAppModel
    }

    // 🎬 CLOSE FINALIZER
    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            launcherModuleRoot.menuOpen = false;
        }
    }

    // 🔓 PUBLIC INTERFACE
    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        menuCard.targetX = -655;
        menuCard.targetOpacity = 0.0;

        rootScope.requestOpen(appLauncherModal);
        menuOpen = true;

        slideInAnimation.start();

        appScanner.running = false;
        appScanner.running = true;
    }

    function closeMenu(): void {
        menuCard.targetX = -655;
        menuCard.targetOpacity = 0.0;

        closeTimer.start();
    }

    // 🔄 GLOBAL CLEANUP LISTENER
    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== appLauncherModal && menuOpen) {
                closeMenu();
            }
        }
    }

    function getLaunchCommand(binString) {
        let cleanBin = binString.trim().toLowerCase();
        
        if (cleanBin === "nautilus" || cleanBin.includes("nautilus")) {
            return ["gtk-launch", "org.gnome.Nautilus.desktop"];
        } else if (cleanBin === "thunar") {
            return ["gtk-launch", "thunar.desktop"];
        } else if (cleanBin === "firefox") {
            return ["gtk-launch", "firefox.desktop"];
        }
        
        return ["/bin/sh", "-c", "export $(dbus-launch); " + binString];
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

    // 🔄 PAYLOAD SCANNER
    Process {
        id: appScanner
        running: true
        command: ["python3", "/home/nick/.config/quickshell/vibez/get_apps.py"]

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

    // 🔘 TRIGGER BUTTON
    Rectangle {
        id: triggerButton
        anchors.fill: parent
        color: launcherMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        Text {
            anchors.centerIn: parent
            text: "󰣇" 
            font.family: "Rubik"
            font.pixelSize: 24
            color: "#cdd6f4" 
        }

        MouseArea {
            id: launcherMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    // 🪟 LAUNCHER WINDOW
    PanelWindow {
        id: appLauncherModal
        visible: launcherModuleRoot.menuOpen
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
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
            width: 300 
            height: 300 
            
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: 12
            
            property int targetX: -655
            property real targetOpacity: 0.0

            anchors.leftMargin: targetX
            opacity: targetOpacity

            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 } 
                ParallelAnimation {
                    NumberAnimation { target: menuCard; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: menuCard; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            color: "#9911111b" 
            border.width: 0
            focus: true

            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: 12
            bottomRightRadius: 12

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
                        globalLauncherRunner.command = getLaunchCommand(targetApp.bin);
                        globalLauncherRunner.running = true;
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

            // 🚀 SCREEN-SPACE COUPLING TRACKER
            MouseArea {
                id: globalTracker
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton 
                z: 10 

                property int lastWindowX: -1
                property int lastWindowY: -1
                
                // Track item target boundaries for changing cursor shapes dynamically
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

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: activeSearchQuery === "" ? "Applications" : "Results for '" + activeSearchQuery + "'"
                    font.family: "Rubik"
                    font.pixelSize: 18
                    font.weight: Font.Bold
                    color: "#cdd6f4" 
                    Layout.alignment: Qt.AlignLeft
                    Layout.bottomMargin: 2
                    Layout.topMargin: 4
                }

                ListView {
                    id: appListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: dynamicAppModel
                    
                    property bool keyboardActive: false

                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 60 
                    highlight: null

                    delegate: Item {
                        id: delegateRoot
                        width: appListView.width
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            color: (appListView.currentIndex === index) ? "#313244" : "transparent"
                            radius: 6
                            z: 0 
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12
                            z: 1

                            Item {
                                width: 22
                                height: 22
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    anchors.fill: parent
                                    sourceSize.width: 22
                                    sourceSize.height: 22
                                    visible: model.iconPath !== ""
                                    source: model.iconPath ? "file://" + model.iconPath : ""
                                    fillMode: Image.PreserveAspectFit
                                    clip: true
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: "#45475a"
                                    visible: model.iconPath === ""

                                    Text {
                                        anchors.centerIn: parent
                                        text: model.name.charAt(0).toUpperCase()
                                        font.family: "Rubik"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: "#b4befe"
                                    }
                                }
                            }

                            Text {
                                text: model.name
                                font.family: "Rubik"
                                font.weight: Font.Medium
                                font.pixelSize: 14
                                color: "#cdd6f4"
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
                                globalLauncherRunner.command = getLaunchCommand(model.bin);
                                globalLauncherRunner.running = true;
                                closeMenu();
                            }
                        }
                    }
                }
            }
        }
    }

    // 🏃 APPLICATION RUNNER INTERFACE
    Process {
        id: globalLauncherRunner
        running: false
        stdout: StdioCollector { onTextChanged: { console.log("Launcher Exec Stdout:", text.trim()); } }
        stderr: StdioCollector { onTextChanged: { console.log("Launcher Exec Stderr:", text.trim()); } }
    }
}
