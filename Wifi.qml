import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

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
        command: ["sh", "-c", "if [ -d /sys/class/net ] && expr \"$(ls -d /sys/class/net/*/wireless 2>/dev/null)\" : '.*wireless' >/dev/null; then exit 0; else exit 1; fi"]
        running: true
        onExited: (code) => {
            if (code === 0) {
                wifiRoot.hasWifiCard = true;
                statusWatcher.running = true;
            } else {
                wifiRoot.hasWifiCard = false;
                statusWatcher.running = false;
            }
        }
    }

    Process {
        id: statusWatcher
        command: ["nmcli", "-t", "-f", "ACTIVE,SIGNAL,SSID", "dev", "wifi"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                if (!wifiRoot.hasWifiCard) return;

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
                if (!wifiRoot.hasWifiCard) return;
                wifiNetworksModel.clear();
                let lines = text.split('\n');
                let seenSsids = new Set();

                for (let line of lines) {
                    if (!line.trim()) continue;
                    let parts = line.split(':');

                    if (parts.length >= 4 && parts[0].length > 0) {
                        let ssidName = parts[0];
                        let isActive = parts[3] === "yes";

                        if (seenSsids.has(ssidName) && !isActive) continue;

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
        if (!wifiRoot.wifiEnabled || !wifiRoot.hasWifiCard) return;
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
    Timer { id: transitionBurstTimer; interval: 200; running: false; repeat: true; onTriggered: triggerScan() }
    Timer { id: transitionBurstStopTimer; interval: 4000; running: false; repeat: false; onTriggered: transitionBurstTimer.stop() }
    Timer { id: osdAutohideTimer; interval: 3500; running: false; repeat: false; onTriggered: drawerTemplate.isOpen = false }

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
        color: iconMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
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
                        wifiRoot.signalStrength < 75  ? "network_wifi_3_bar" : "network_wifi")
                    font.family: "Material Symbols Outlined"
                    font.pixelSize: 20
                    color: wifiRoot.wifiEnabled ? (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
                }
            }
        }

        MouseArea {
            id: iconMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: drawerTemplate.isOpen = !drawerTemplate.isOpen
            onContainsMouseChanged: checkUserActivity()
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 340 // Fixed height, standard module behavior
        modalToken: "wifi"
        anchorTop: false

        onIsOpenChanged: {
            if (isOpen) {
                wifiRoot.enteringPassword = false;
                wifiRoot.showingForgetConfirm = false;
                triggerScan();
                checkUserActivity();
                mainContainerLayout.forceActiveFocus();
            }
        }

        MouseArea {
            id: cardHoverTracker
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: checkUserActivity()
            onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
        }

        ColumnLayout {
            id: mainContainerLayout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            focus: true

            Keys.onPressed: (event) => { if (event.key === Qt.Key_Escape) { drawerTemplate.isOpen = false; event.accepted = true; } }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Wi-Fi"
                    font.family: "Rubik"; font.pixelSize: 15; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                    Layout.alignment: Qt.AlignVCenter
                }
                RowLayout {
                    spacing: 4
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    opacity: (wifiRoot.wifiEnabled && wifiRoot.ssid !== "Disconnected" && wifiRoot.ssid !== "") ? 1.0 : 0.0
                    Item { Layout.fillWidth: true }
                    Text { text: "Connected to:"; font.family: "Rubik"; font.pixelSize: 11; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff" }
                    Text {
                        text: wifiRoot.ssid
                        font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold
                        color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                        elide: Text.ElideRight; Layout.maximumWidth: 100
                    }
                    Item { Layout.fillWidth: true }
                }
                Rectangle {
                    width: 50; height: 24; radius: 12
                    color: wifiRoot.wifiEnabled ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                    Rectangle {
                        width: 18; height: 18; radius: 9; color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
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

            Rectangle { Layout.fillWidth: true; height: 1; color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff" }

            StackLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                currentIndex: !wifiRoot.wifiEnabled ? 3 : (wifiRoot.enteringPassword ? 1 : (wifiRoot.showingForgetConfirm ? 2 : 0))

                ListView {
                    id: networkListView; model: wifiNetworksModel; clip: true; spacing: 4
                    delegate: Rectangle {
                        width: networkListView.width; height: 34; color: itemMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"; radius: 4
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 8
                            Text { text: model.isActive ? "🛜" : ""; font.pixelSize: 11 }
                            Text { text: model.ssidName; font.family: "Rubik"; font.pixelSize: 12; font.weight: model.isActive ? Font.Bold : Font.Normal; color: rootScope.theme ? (model.isActive ? rootScope.theme.theme_primary : rootScope.theme.theme_fg) : "#ffffff"; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: model.secured ? "lock" : ""; font.family: "Material Symbols Outlined"; font.pixelSize: 14; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff" }
                            Text { text: model.bars; font.family: "Rubik"; font.pixelSize: 11; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff" }
                        }
                        MouseArea {
                            id: itemMouseArea; anchors.fill: parent; hoverEnabled: true
                            onClicked: {
                                wifiRoot.selectedSsid = model.ssidName;
                                if (model.isActive) wifiRoot.showingForgetConfirm = true;
                                else if (model.secured) { wifiRoot.enteringPassword = true; passInputField.text = ""; passInputField.forceActiveFocus(); }
                                else connectToNetwork(model.ssidName, "");
                            }
                        }
                    }
                }
                ColumnLayout {
                    spacing: 10; Layout.fillWidth: true
                    Text { text: "Connect to: " + wifiRoot.selectedSsid; font.family: "Rubik"; font.pixelSize: 12; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                    TextField {
                        id: passInputField; Layout.fillWidth: true; height: 32; echoMode: TextInput.Password
                        placeholderText: "Enter passkey..."; font.family: "Rubik"; font.pixelSize: 12; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                        background: Rectangle { color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"; border.color: parent.activeFocus ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"); border.width: 1; radius: 4 }
                        Keys.onPressed: (event) => { if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) connectToNetwork(wifiRoot.selectedSsid, text) }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Button {
                            Layout.fillWidth: true; contentItem: Text { text: "Cancel"; font.family: "Rubik"; font.pixelSize: 12; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { color: parent.hovered ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"); radius: 4 }
                            onClicked: wifiRoot.enteringPassword = false
                        }
                        Button {
                            Layout.fillWidth: true; contentItem: Text { text: "Connect"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { color: parent.hovered ? (rootScope.theme ? rootScope.theme.theme_outline : "#40ffffff") : (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"); radius: 4 }
                            onClicked: connectToNetwork(wifiRoot.selectedSsid, passInputField.text)
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
                ColumnLayout {
                    spacing: 10; Layout.fillWidth: true
                    Text { text: "Connected to: " + wifiRoot.selectedSsid; font.family: "Rubik"; font.pixelSize: 12; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Button {
                            Layout.fillWidth: true; contentItem: Text { text: "Back"; font.family: "Rubik"; font.pixelSize: 12; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { color: parent.hovered ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"); radius: 4 }
                            onClicked: wifiRoot.showingForgetConfirm = false
                        }
                        Button {
                            Layout.fillWidth: true; contentItem: Text { text: "Forget"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff"; horizontalAlignment: Text.AlignHCenter }
                            background: Rectangle { color: parent.hovered ? (rootScope.theme ? rootScope.theme.theme_outline : "#40ffffff") : (rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"); radius: 4 }
                            onClicked: forgetNetwork(wifiRoot.selectedSsid)
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
                Text {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    text: "Wi-Fi is turned off"; font.family: "Rubik"; font.pixelSize: 13; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
}
