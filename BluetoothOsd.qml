import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: bluetoothRoot
    implicitWidth: 32
    implicitHeight: 32

    property bool isPowered: false
    property bool isConnected: false
    property string currentTab: "paired" 
    property bool isScanning: false

    ListModel { id: pairedDevicesModel }
    ListModel { id: discoveredDevicesModel }

    onCurrentTabChanged: {
        if (!bluetoothRoot.isPowered) return;
        if (currentTab === "paired") {
            deviceScraper.running = false;
            deviceScraper.running = true;
        } else if (currentTab === "discover") {
            discoveryScraper.running = false;
            discoveryScraper.running = true;
        }
    }

    // 📡 STATUS WATCHER
    Process {
        id: bluetoothWatcher
        command: ["/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "status"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                const cleanText = text.trim();
                if (!cleanText) return;
                try {
                    const state = JSON.parse(cleanText);
                    bluetoothRoot.isPowered = state.powered;
                    bluetoothRoot.isConnected = state.connected;
                } catch(e) {}
            }
        }
    }

    // 📡 PAIRED REFRESHER
    Process {
        id: deviceScraper
        command: ["/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "paired"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                const rawOutput = text.trim();
                if (!rawOutput) return;

                const lines = rawOutput.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                pairedDevicesModel.clear();
                
                for (let i = 0; i < lines.length; i++) {
                    const segments = lines[i].split("|");
                    if (segments.length >= 3) {
                        pairedDevicesModel.append({
                            macAddress: segments[0],
                            isDeviceConnected: segments[1] === "true",
                            deviceName: segments[2]
                        });
                    }
                }
            }
        }
    }

    // 📡 DISCOVERY LIVE SCANNER RUNNER
    Process {
        id: scanAction
        command: ["/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "scan"]
        onExited: bluetoothRoot.isScanning = false
    }

    // 📡 DISCOVERED REFRESHER
    Process {
        id: discoveryScraper
        command: ["/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "discover"]
        running: false
        stdout: StdioCollector {
            onTextChanged: {
                const rawOutput = text.trim();
                if (!rawOutput) return;

                const lines = rawOutput.split("\n").map(l => l.trim()).filter(l => l.length > 0);
                discoveredDevicesModel.clear();
                
                for (let i = 0; i < lines.length; i++) {
                    const segments = lines[i].split("|");
                    if (segments.length >= 2 && segments[1].trim() !== "") {
                        discoveredDevicesModel.append({
                            macAddress: segments[0],
                            deviceName: segments[1]
                        });
                    }
                }
            }
        }
    }

    // 🔄 CORE OPERATION ACTIONS
    Process { id: bluetoothToggleAction; command: ["/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "toggle"] }
    Process { id: deviceConnectionAction }
    Process { id: pairAction }

    function triggerScan() {
        if (!bluetoothRoot.isPowered || bluetoothRoot.isScanning) return;
        bluetoothRoot.isScanning = true;
        scanAction.running = false;
        scanAction.running = true;
    }

    Timer {
        interval: 4000
        running: bluetoothOverlayModal.visible
        repeat: true
        onTriggered: {
            bluetoothWatcher.running = false;
            bluetoothWatcher.running = true;
            if (bluetoothRoot.currentTab === "paired") {
                deviceScraper.running = false;
                deviceScraper.running = true;
            } else if (bluetoothRoot.currentTab === "discover") {
                discoveryScraper.running = false;
                discoveryScraper.running = true;
            }
        }
    }

    Timer {
        interval: 5000
        running: !bluetoothOverlayModal.visible
        repeat: true
        onTriggered: {
            bluetoothWatcher.running = false;
            bluetoothWatcher.running = true;
        }
    }

    // 🎨 UI PANEL TRIGGER BUTTON
    Rectangle {
        anchors.fill: parent
        color: bluetoothMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        Text {
            anchors.centerIn: parent
            text: bluetoothRoot.isPowered ? (bluetoothRoot.isConnected ? "󰂱" : "󰂯") : "󰂲"
            font.family: "Rubik"
            font.pixelSize: 20
            color: bluetoothRoot.isConnected ? "#74c7ec" : 
                   bluetoothRoot.isPowered   ? "#cdd6f4" : "#585b70"
        }

        MouseArea {
            id: bluetoothMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                bluetoothOverlayModal.visible = !bluetoothOverlayModal.visible;
                if (bluetoothOverlayModal.visible) {
                    bluetoothRoot.currentTab = "paired";
                    deviceScraper.running = false;
                    deviceScraper.running = true;
                }
            }
        }
    }

    // ==========================================
    // 🪟 OVERLAY CONTROL MODAL WINDOW
    // ==========================================
    PanelWindow {
        id: bluetoothOverlayModal
        visible: false
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        
        // 🎯 THE FIX: Explicitly request keyboard processing vectors from the wayland compositor
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        // Fire focus request triggers directly down to the structural frame container when visible
        onVisibleChanged: {
            if (visible) popupMenuFrame.forceActiveFocus();
        }

        MouseArea { anchors.fill: parent; onClicked: bluetoothOverlayModal.visible = false }

        Rectangle {
            id: popupMenuFrame
            width: 280; height: 350
            x: parent.width - width - 80; y: 10 
            color: "#EE1e1e2e"; border.color: "#313244"; border.width: 1; radius: 12
            
            // 🎯 THE FIX: Intercept keyboard escape escape sequences to safely toggle hidden
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    bluetoothOverlayModal.visible = false;
                    event.accepted = true;
                }
            }

            MouseArea { anchors.fill: parent; onPressed: mouse.accepted = true }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 10

                // HEADER SECTION
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Bluetooth"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#cdd6f4" }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 50; height: 24; radius: 12
                        color: bluetoothRoot.isPowered ? "#a6e3a1" : "#313244"
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: "#11111b"
                            anchors.verticalCenter: parent.verticalCenter
                            x: bluetoothRoot.isPowered ? 28 : 4
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bluetoothToggleAction.running = false; bluetoothToggleAction.running = true;
                                bluetoothRoot.isPowered = !bluetoothRoot.isPowered;
                                if (!bluetoothRoot.isPowered) { pairedDevicesModel.clear(); discoveredDevicesModel.clear(); }
                            }
                        }
                    }
                }

                // NAVIGATION TABS SECTION
                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    visible: bluetoothRoot.isPowered

                    // Tab Button: My Devices
                    Rectangle {
                        Layout.fillWidth: true; height: 26; radius: 6
                        color: bluetoothRoot.currentTab === "paired" ? "#313244" : "transparent"
                        Text { text: "My Devices"; font.family: "Rubik"; font.pixelSize: 12; color: "#cdd6f4"; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bluetoothRoot.currentTab = "paired" }
                    }

                    // Tab Button: Discover New Devices
                    Rectangle {
                        Layout.fillWidth: true; height: 26; radius: 6
                        color: bluetoothRoot.currentTab === "discover" ? "#313244" : "transparent"
                        RowLayout {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "Discover"; font.family: "Rubik"; font.pixelSize: 12; color: "#cdd6f4" }
                            Text {
                                text: ""; font.family: "FontAwesome"
                                font.pixelSize: 10; color: "#a6e3a1"
                                visible: bluetoothRoot.isScanning
                                RotationAnimator on rotation { loops: Animation.Infinite; from: 0; to: 360; running: bluetoothRoot.isScanning; duration: 1000 }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                bluetoothRoot.currentTab = "discover";
                                bluetoothRoot.triggerScan();
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

                // PANE MULTIPLEXER STACK
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                    // PANE 1: PAIRED LIST
                    ListView {
                        id: pairedListView
                        anchors.fill: parent; clip: true; spacing: 4
                        model: pairedDevicesModel
                        visible: bluetoothRoot.currentTab === "paired" && bluetoothRoot.isPowered

                        Text { 
                            anchors.centerIn: parent; 
                            text: bluetoothRoot.isPowered ? "No paired devices found" : "Bluetooth is turned off"; 
                            font.family: "Rubik"; font.pixelSize: 12; color: "#585b70"; 
                            visible: pairedListView.count === 0 || !bluetoothRoot.isPowered 
                        }
                        delegate: Item {
                            width: pairedListView.width; height: 36
                            Rectangle {
                                anchors.fill: parent; color: pArea.containsMouse ? "#313244" : "transparent"; radius: 6
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 10
                                    Text { text: model.isDeviceConnected ? "󰂱" : "󰂯"; font.family: "Rubik"; font.pixelSize: 16; color: model.isDeviceConnected ? "#a6e3a1" : "#a6adc8" }
                                    Text { text: model.deviceName; font.family: "Rubik"; font.pixelSize: 13; color: "#cdd6f4"; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: model.isDeviceConnected ? "Disconnect" : "Connect"; font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold; color: model.isDeviceConnected ? "#f38ba8" : "#b4befe"; visible: pArea.containsMouse }
                                }
                                MouseArea {
                                    id: pArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const actionType = model.isDeviceConnected ? "disconnect" : "connect";
                                        deviceConnectionAction.command = ["bluetoothctl", actionType, model.macAddress];
                                        deviceConnectionAction.running = true;
                                        pairedDevicesModel.setProperty(index, "isDeviceConnected", !model.isDeviceConnected);
                                    }
                                }
                            }
                        }
                    }

                    // PANE 2: DISCOVERY LIVE LIST
                    ListView {
                        id: discoveryListView
                        anchors.fill: parent; clip: true; spacing: 4
                        model: discoveredDevicesModel
                        visible: bluetoothRoot.currentTab === "discover" && bluetoothRoot.isPowered

                        Text { 
                            anchors.centerIn: parent; 
                            text: bluetoothRoot.isPowered ? (bluetoothRoot.isScanning ? "Scanning for local signals..." : "No new devices found") : "Bluetooth is turned off"; 
                            font.family: "Rubik"; font.pixelSize: 12; color: "#585b70"; 
                            visible: discoveryListView.count === 0 || !bluetoothRoot.isPowered 
                        }
                        delegate: Item {
                            width: discoveryListView.width; height: 36
                            Rectangle {
                                anchors.fill: parent; color: dArea.containsMouse ? "#313244" : "transparent"; radius: 6
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 10
                                    Text { text: ""; font.family: "Rubik"; font.pixelSize: 14; color: "#b4befe" }
                                    Text { text: model.deviceName; font.family: "Rubik"; font.pixelSize: 13; color: "#bac2de"; Layout.fillWidth: true; elide: Text.ElideRight }
                                    Text { text: "Pair"; font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold; color: "#a6e3a1"; visible: dArea.containsMouse }
                                }
                                MouseArea {
                                    id: dArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        pairAction.command = ["bash", "-c", "bluetoothctl pair " + model.macAddress + " && bluetoothctl trust " + model.macAddress + " && bluetoothctl connect " + model.macAddress];
                                        pairAction.running = true;
                                        bluetoothRoot.currentTab = "paired";
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