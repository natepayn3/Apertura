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
    property bool wifiEnabled: true

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

    Process { id: nmcActionExecutor; command: []; running: false }

    function triggerScan(): void { 
        if (!wifiRoot.wifiEnabled) return;
        networkScanner.running = true; 
        statusWatcher.running = true; 
    }
    
    function startTransitionBurst(): void {
        transitionBurstTimer.restart();
        transitionBurstStopTimer.restart();
    }

    function forgetNetwork(targetSsid): void {
        nmcActionExecutor.command = ["nmcli", "connection", "delete", targetSsid];
        nmcActionExecutor.running = true;
        wifiRoot.showingForgetConfirm = false;
        triggerScan();
        startTransitionBurst();
    }
    
    function connectToNetwork(targetSsid, password): void {
        nmcActionExecutor.command = password !== "" 
            ? ["nmcli", "dev", "wifi", "connect", targetSsid, "password", password]
            : ["nmcli", "dev", "wifi", "connect", targetSsid];
        nmcActionExecutor.running = true;
        wifiRoot.enteringPassword = false;
        triggerScan();
        startTransitionBurst();
    }

    Timer { interval: 20000; running: wifiRoot.hasWifiCard && wifiRoot.wifiEnabled; repeat: true; onTriggered: triggerScan() }
    
    Timer {
        id: transitionBurstTimer
        interval: 200
        running: false
        repeat: true
        onTriggered: triggerScan()
    }

    Timer {
        id: transitionBurstStopTimer
        interval: 4000
        running: false
        repeat: false
        onTriggered: transitionBurstTimer.stop()
    }

    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    Timer { id: closeTimer; interval: 180; repeat: false; onTriggered: wifiRoot.menuOpen = false }

    function openMenu(): void {
        popupMenuFrame.targetX = -655; popupMenuFrame.targetOpacity = 0.0;
        rootScope.requestOpen("wifi"); wifiRoot.menuOpen = true; wifiRoot.enteringPassword = false; wifiRoot.showingForgetConfirm = false;
        slideInAnimation.start(); triggerScan(); checkUserActivity();
    }
    
    function closeMenu(): void { popupMenuFrame.targetX = -655; popupMenuFrame.targetOpacity = 0.0; closeTimer.start(); }

    function checkUserActivity() {
        if (iconMouseArea.containsMouse || cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else {
            osdAutohideTimer.restart(); 
        }
    }

    Rectangle {
        id: wifiHitbox
        anchors.fill: parent
        color: iconMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 0 

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 20; height: 20

                Text {
                    id: wifiIcon
                    anchors.centerIn: parent
                    text: !wifiRoot.wifiEnabled ? "signal_wifi_off" : (wifiRoot.ssid === "Disconnected" || wifiRoot.ssid === "" ? "perm_scan_wifi" : 
                          wifiRoot.signalStrength < 25  ? "network_wifi_1_bar" : 
                          wifiRoot.signalStrength < 50  ? "network_wifi_2_bar" : 
                          wifiRoot.signalStrength < 75  ? "network_wifi_3_bar" : 
                                                          "network_wifi")
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 20
                    color: wifiRoot.wifiEnabled ? "#ffffff" : "#59ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        MouseArea {
            id: iconMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: wifiRoot.menuOpen ? closeMenu() : openMenu()
            onContainsMouseChanged: checkUserActivity()
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() { if (rootScope.activeModal !== "wifi" && menuOpen) closeMenu(); }
    }

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

            MouseArea {
                id: cardHoverTracker
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: checkUserActivity()
                onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
            }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    
                    Text { 
                        text: "Wi-Fi"
                        font.family: "Rubik"; font.pixelSize: 15; font.weight: Font.Bold; color: "#ffffff" 
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    RowLayout {
                        spacing: 4
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        opacity: (wifiRoot.wifiEnabled && wifiRoot.ssid !== "Disconnected" && wifiRoot.ssid !== "") ? 1.0 : 0.0
                        
                        Item { Layout.fillWidth: true }
                        Text { text: "Connected to:"; font.family: "Rubik"; font.pixelSize: 11; color: "#59ffffff" }
                        Text { 
                            text: wifiRoot.ssid
                            font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold
                            color: "#ffffff"
                            elide: Text.ElideRight; Layout.maximumWidth: 100 
                        }
                        Item { Layout.fillWidth: true }
                    }

                    Rectangle {
                        width: 50; height: 24; radius: 12
                        color: wifiRoot.wifiEnabled ? "#45ffffff" : "#26ffffff"
                        Layout.alignment: Qt.AlignVCenter
                        
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: "#11111b"
                            anchors.verticalCenter: parent.verticalCenter
                            x: wifiRoot.wifiEnabled ? 28 : 4
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                        
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wifiRoot.wifiEnabled = !wifiRoot.wifiEnabled;
                                nmcActionExecutor.command = ["nmcli", "radio", "wifi", wifiRoot.wifiEnabled ? "on" : "off"];
                                nmcActionExecutor.running = true;
                                if (!wifiRoot.wifiEnabled) {
                                    wifiNetworksModel.clear();
                                    wifiRoot.signalStrength = 0;
                                    wifiRoot.ssid = "Disconnected";
                                } else {
                                    triggerScan();
                                    startTransitionBurst();
                                }
                                checkUserActivity();
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#26ffffff" }

                StackLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    currentIndex: !wifiRoot.wifiEnabled ? 3 : (wifiRoot.enteringPassword ? 1 : (wifiRoot.showingForgetConfirm ? 2 : 0))

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

                    Text {
                        id: disabledPlaceholder
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: "Wi-Fi is turned off"
                        font.family: "Rubik"; font.pixelSize: 13; color: "#59ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
