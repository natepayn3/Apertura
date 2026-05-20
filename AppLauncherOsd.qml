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

    ListModel {
        id: dynamicAppModel
    }

    // 🔓 PUBLIC INTERFACE
    function toggleMenu() {
        appLauncherModal.visible = !appLauncherModal.visible;
        if (appLauncherModal.visible) {
            appScanner.running = false;
            appScanner.running = true;
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
            color: launcherMouseArea.containsMouse ? "#afbaff" : "#cdd6f4"
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
        visible: false
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea {
            anchors.fill: parent
            onPressed: appLauncherModal.visible = false
        }

        Rectangle {
            id: menuCard
            width: 300 
            height: 450 
            x: 16
            y: 10 
            color: "#EE1e1e2e" 
            border.color: "#313244"   
            border.width: 1
            radius: 12

            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    appLauncherModal.visible = false;
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_Down) {
                    if (appListView.currentIndex < appListView.count - 1) {
                        appListView.currentIndex++;
                    }
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Up) {
                    if (appListView.currentIndex > 0) {
                        appListView.currentIndex--;
                    }
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (appListView.currentIndex >= 0 && appListView.currentIndex < appListView.count) {
                        let targetApp = dynamicAppModel.get(appListView.currentIndex);
                        
                        // 🎯 Direct array pass bypassing subshell string parsing errors
                        globalLauncherRunner.command = [targetApp.bin];
                        globalLauncherRunner.running = true;
                        appLauncherModal.visible = false;
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
                anchors.fill: parent
                onPressed: mouse.accepted = true
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
                    color: "#a6adc8"
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
                    
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 60 
                    highlight: Rectangle {
                        width: appListView.width
                        height: 36
                        color: "#313244"
                        radius: 6
                        z: 0 
                    }

                    Connections {
                        target: appLauncherModal
                        function onVisibleChanged() {
                            if (appLauncherModal.visible) {
                                activeSearchQuery = "";
                                filterApps("");
                                appListView.currentIndex = 0;
                                appListView.positionViewAtBeginning();
                                menuCard.forceActiveFocus();
                            }
                        }
                    }

                    delegate: Item {
                        width: appListView.width
                        height: 36

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 12

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
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onPositionChanged: appListView.currentIndex = index
                            
                            onClicked: {
                                // 🎯 Matches keyboard loop with direct target array routing
                                globalLauncherRunner.command = [model.bin];
                                globalLauncherRunner.running = true;
                                appLauncherModal.visible = false;
                            }
                        }
                    }
                }
            }
        }
    }

    // 🔬 DEBUG MONITORING ENGINE
    Process {
        id: globalLauncherRunner
        running: false
        stdout: StdioCollector { onTextChanged: { console.log("Launcher Exec Stdout:", text.trim()); } }
        stderr: StdioCollector { onTextChanged: { console.log("Launcher Exec Stderr:", text.trim()); } }
    }
}