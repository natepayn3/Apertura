import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: wifiRoot
    
    property bool hasWifiCard: false
    
    implicitWidth: hasWifiCard ? 32 : 0
    implicitHeight: hasWifiCard ? 32 : 0
    visible: hasWifiCard

    property int signalStrength: 0
    property string ssid: "Disconnected"
    property bool menuOpen: false
    property bool enteringPassword: false
    property bool showingForgetConfirm: false 
    property string selectedSsid: ""

    // ⚡ Hardware Detection: Scans sysfs net paths for any card exposing wireless capabilities
    Process {
        id: hardwareCheck
        command: ["sh", "-c", "ls /sys/class/net/*/wireless >/dev/null 2>&1"]
        running: true
        onExited: (code) => {
            if (code === 0) {
                wifiRoot.hasWifiCard = true;
                statusWatcher.running = true;
            } else {
                wifiRoot.hasWifiCard = false;
            }
        }
    }

    // 📡 Status Watcher: Resolves current connection states
    Process {
        id: statusWatcher
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "dev", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = text.split('\n');
                let foundActive = false;
                for (let line of lines) {
                    let parts = line.split(':');
                    if (parts.length >= 3 && parts[0] === "yes") { 
                        wifiRoot.signalStrength = parseInt(parts[1]) || 0;
                        wifiRoot.ssid = parts[2];
                        foundActive = true;
                        break;
                    }
                }
                if (!foundActive) {
                    wifiRoot.signalStrength = 0;
                    wifiRoot.ssid = "Disconnected";
                }
            }
        }
    }

    // 🔍 Network Scanner: Pulls surrounding endpoints into the model
    ListModel { id: wifiNetworksModel }
    Process {
        id: networkScanner
        command: ["nmcli", "-t", "-f", "SSID,SECURITY,BARS,ACTIVE", "dev", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                wifiNetworksModel.clear();
                let lines = text.split('\n');
                let seenSsids = new Set();
                
                for (let line of lines) {
                    if (!line.trim()) continue;
                    let parts = line.split(':');
                    
                    if (parts.length >= 4 && parts[0].length > 0) {
                        let ssidName = parts[0];
                        let isActive = parts[3] === "yes";
                        
                        if (seenSsids.has(ssidName) && !isActive) {
                            continue;
                        }
                        
                        if (isActive && seenSsids.has(ssidName)) {
                            for (let i = 0; i < wifiNetworksModel.count; i++) {
                                if (wifiNetworksModel.get(i).ssidName === ssidName) {
                                    wifiNetworksModel.remove(i);
                                    break;
                                }
                            }
                        }
                        
                        seenSsids.add(ssidName);
                        
                        wifiNetworksModel.append({
                            "ssidName": ssidName,
                            "secured": parts[1] !== "" && parts[1] !== "--",
                            "bars": parts[2],
                            "isActive": isActive
                        });
                    }
                }
            }
        }
    }

    // 🛠️ Action Executer: Handles backend configuration tasks asynchronously
    Process { id: nmcActionExecutor; command: []; running: false }

    function triggerScan(): void { networkScanner.running = true; statusWatcher.running = true; }
    
    function forgetNetwork(targetSsid): void {
        nmcActionExecutor.command = ["nmcli", "connection", "delete", targetSsid];
        nmcActionExecutor.running = true;
        wifiRoot.showingForgetConfirm = false;
        triggerScan();
    }
    
    function connectToNetwork(targetSsid, password): void {
        nmcActionExecutor.command = password !== "" 
            ? ["nmcli", "dev", "wifi", "connect", targetSsid, "password", password]
            : ["nmcli", "dev", "wifi", "connect", targetSsid];
        nmcActionExecutor.running = true;
        wifiRoot.enteringPassword = false;
        triggerScan();
    }

    // 🕒 Sync hardware layers regularly
    Timer { interval: 12000; running: wifiRoot.hasWifiCard; repeat: true; onTriggered: triggerScan() }
    Timer { id: closeTimer; interval: 180; repeat: false; onTriggered: wifiRoot.menuOpen = false }

    function openMenu(): void {
        popupMenuFrame.targetX = -655; popupMenuFrame.targetOpacity = 0.0;
        rootScope.requestOpen("wifi"); wifiRoot.menuOpen = true; wifiRoot.enteringPassword = false; wifiRoot.showingForgetConfirm = false;
        slideInAnimation.start(); triggerScan();
    }
    
    function closeMenu(): void { popupMenuFrame.targetX = -655; popupMenuFrame.targetOpacity = 0.0; closeTimer.start(); }

    // ==========================================
    // 📶 WI-FI ICON TRIGGER MODULE
    // ==========================================
    Rectangle {
        id: wifiHitbox
        anchors.fill: parent
        color: batteryMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 0 

        Item {
            anchors.centerIn: parent
            width: 20; height: 20

            Text {
                id: wifiIcon
                anchors.centerIn: parent
                text: wifiRoot.signalStrength === 0 ? "signal_cellular_nodata" : 
                      wifiRoot.signalStrength < 35  ? "signal_cellular_1_bar" : 
                      wifiRoot.signalStrength < 65  ? "signal_cellular_2_bar" : 
                      wifiRoot.signalStrength < 85  ? "signal_cellular_3_bar" : 
                                                      "signal_cellular_4_bar"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        MouseArea {
            id: batteryMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wifiRoot.menuOpen ? closeMenu() : openMenu()
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() { if (rootScope.activeModal !== "wifi" && menuOpen) closeMenu(); }
    }

    // ==========================================
    // 🪟 OVERLAY CONTROL CARD
    // ==========================================
    PanelWindow {
        id: wifiOverlayModal; visible: wifiRoot.menuOpen; color: "transparent"
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "quickshell-overlay"; WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        onVisibleChanged: { if (visible && wifiRoot.menuOpen) popupMenuFrame.forceActiveFocus(); }
        MouseArea { anchors.fill: parent; onClicked: closeMenu() }

        Rectangle {
            id: popupMenuFrame
            width: 320; height: 340 
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.bottomMargin: 12
            property int targetX: -655; property real targetOpacity: 0.0
            anchors.leftMargin: targetX; opacity: targetOpacity

            SequentialAnimation {
                id: slideInAnimation; PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupMenuFrame; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupMenuFrame; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }
            Behavior on anchors.leftMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
            
            color: "#9911111b"; border.width: 0; radius: 0; focus: true
            Keys.onPressed: (event) => { if (event.key === Qt.Key_Escape) { closeMenu(); event.accepted = true; } }
            MouseArea { anchors.fill: parent; onPressed: (mouse) => { mouse.accepted = true; } }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Wi-Fi"; font.family: "Rubik"; font.pixelSize: 15; font.weight: Font.Bold; color: "#ffffff" }
                    Item { Layout.fillWidth: true }
                    
                    RowLayout {
                        spacing: 4
                        Text { text: "Connected to:"; font.family: "Rubik"; font.pixelSize: 11; color: "#59ffffff" }
                        Text { 
                            text: wifiRoot.ssid
                            font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold
                            color: "#ffffff"
                            elide: Text.ElideRight; Layout.maximumWidth: 100 
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#26ffffff" }

                StackLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    currentIndex: wifiRoot.enteringPassword ? 1 : (wifiRoot.showingForgetConfirm ? 2 : 0)

                    ListView {
                        id: networkListView; model: wifiNetworksModel; clip: true; spacing: 4
                        delegate: Rectangle {
                            width: networkListView.width; height: 34; color: itemMouseArea.containsMouse ? "#26ffffff" : "transparent"; radius: 4
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                                Text { text: model.isActive ? "🛜" : ""; font.pixelSize: 11 }
                                Text { text: model.ssidName; font.family: "Rubik"; font.pixelSize: 12; font.weight: model.isActive ? Font.Bold : Font.Normal; color: "#ffffff"; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: model.secured ? "lock" : ""; font.family: "Material Symbols Outlined"; font.pixelSize: 14; color: "#59ffffff" }
                                Text { text: model.bars; font.family: "Rubik"; font.pixelSize: 11; color: "#59ffffff" }
                            }
                            MouseArea {
                                id: itemMouseArea; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    wifiRoot.selectedSsid = model.ssidName;
                                    if (model.isActive) {
                                        wifiRoot.showingForgetConfirm = true;
                                    } else if (model.secured) {
                                        wifiRoot.enteringPassword = true;
                                        passInputField.text = "";
                                        passInputField.forceActiveFocus();
                                    } else {
                                        connectToNetwork(model.ssidName, "");
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 10; Layout.fillWidth: true
                        Text { text: "Connect to: " + wifiRoot.selectedSsid; font.family: "Rubik"; font.pixelSize: 12; color: "#ffffff" }
                        
                        TextField {
                            id: passInputField; Layout.fillWidth: true; height: 32; echoMode: TextInput.Password
                            placeholderText: "Enter passkey..."; font.family: "Rubik"; font.pixelSize: 12; color: "#ffffff"
                            background: Rectangle { color: "#11111b"; border.color: parent.activeFocus ? "#ffffff" : "#26ffffff"; border.width: 1; radius: 4 }
                            Keys.onPressed: (event) => { if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) connectToNetwork(wifiRoot.selectedSsid, text) }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Button {
                                Layout.preferredWidth: 140; Layout.fillWidth: true
                                contentItem: Text { text: "Cancel"; font.family: "Rubik"; font.pixelSize: 12; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                                background: Rectangle { color: parent.hovered ? "#26ffffff" : "#11111b"; radius: 4 }
                                onClicked: wifiRoot.enteringPassword = false
                            }
                            Button {
                                Layout.preferredWidth: 140; Layout.fillWidth: true
                                contentItem: Text { text: "Connect"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                                background: Rectangle { color: parent.hovered ? "#40ffffff" : "#11111b"; radius: 4 }
                                onClicked: connectToNetwork(wifiRoot.selectedSsid, passInputField.text)
                            }
                        }
                        Item { Layout.fillHeight: true } 
                    }

                    ColumnLayout {
                        spacing: 10; Layout.fillWidth: true
                        Text { text: "Connected to: " + wifiRoot.selectedSsid; font.family: "Rubik"; font.pixelSize: 12; color: "#ffffff" }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Button {
                                Layout.preferredWidth: 140; Layout.fillWidth: true
                                contentItem: Text { text: "Back"; font.family: "Rubik"; font.pixelSize: 12; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                                background: Rectangle { color: parent.hovered ? "#26ffffff" : "#11111b"; radius: 4 }
                                onClicked: wifiRoot.showingForgetConfirm = false
                            }
                            Button {
                                Layout.preferredWidth: 140; Layout.fillWidth: true
                                contentItem: Text { text: "Forget"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                                background: Rectangle { color: parent.hovered ? "#40ffffff" : "#11111b"; radius: 4 }
                                onClicked: forgetNetwork(wifiRoot.selectedSsid)
                            }
                        }
                        Item { Layout.fillHeight: true } 
                    }
                }
            }
        }
    }
}
