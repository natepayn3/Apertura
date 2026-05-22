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

    // Controls actual PanelWindow visibility
    property bool menuOpen: false

    ListModel { id: pairedDevicesModel }
    ListModel { id: discoveredDevicesModel }

    // Smart auto-hide countdown tracker
    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    // 🎬 CLOSE FINALIZER
    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            bluetoothRoot.menuOpen = false;
            rootScope.dismissAll();
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
        // Reset hidden baseline coordinates before window mapping
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;

        rootScope.requestOpen(bluetoothOverlayModal);
        menuOpen = true;

        // Drive entry transition timeline sequentially
        slideInAnimation.start();
        bluetoothRoot.currentTab = "paired";
        refreshPairedList();
        checkUserActivity();
    }

    function closeMenu(): void {
        // Animate out while layer surface remains active
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;

        closeTimer.start();
    }

    // Helper logic to cleanly handle user presence changes
    function checkUserActivity() {
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (bluetoothOverlayModal.visible && menuOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    function refreshStatus() {
        if (!bluetoothWatcher.running) {
            bluetoothWatcher.running = true;
        }
    }

    function refreshPairedList() {
        if (!bluetoothRoot.isPowered) return;
        if (!deviceScraper.running) {
            deviceScraper.running = true;
        }
    }

    function refreshDiscoverList() {
        if (!bluetoothRoot.isPowered) return;
        if (!discoveryScraper.running) {
            discoveryScraper.running = true;
        }
    }

    onCurrentTabChanged: {
        if (currentTab === "paired") {
            refreshPairedList();
        } else if (currentTab === "discover") {
            refreshDiscoverList();
        }
    }

    // 📡 STATUS WATCHER
    Process {
        id: bluetoothWatcher
        command: ["/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "status"]
        running: true
        onExited: running = false 
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
        onExited: running = false 
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
        command: ["timeout", "5s", "/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "scan"]
        running: false
        onExited: {
            running = false;
            bluetoothRoot.isScanning = false;
            refreshDiscoverList(); 
        }
    }

    // 📡 DISCOVERED REFRESHER
    Process {
        id: discoveryScraper
        command: ["/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "discover"]
        running: false
        onExited: running = false 
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
    Process { 
        id: bluetoothToggleAction; 
        command: ["/home/nick/.config/quickshell/vibez/bluetooth_control.sh", "toggle"] 
        onExited: { running = false; refreshStatus(); }
    }
    Process { 
        id: deviceConnectionAction 
        onExited: { running = false; refreshStatus(); refreshPairedList(); }
    }
    Process { 
        id: pairAction 
        onExited: { running = false; refreshStatus(); refreshPairedList(); }
    }

    function triggerScan() {
        if (!bluetoothRoot.isPowered || bluetoothRoot.isScanning) return;
        bluetoothRoot.isScanning = true;
        scanAction.running = true;
    }

    // POLL INTERVAL WHEN OVERLAY IS OPEN
    Timer {
        interval: 4000
        running: bluetoothOverlayModal.visible
        repeat: true
        onTriggered: {
            refreshStatus();
            if (bluetoothRoot.currentTab === "paired") {
                refreshPairedList();
            }
        }
    }

    // POLL INTERVAL WHEN OVERLAY IS CLOSED
    Timer {
        interval: 5000
        running: !bluetoothOverlayModal.visible
        repeat: true
        onTriggered: refreshStatus()
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
            onClicked: toggleMenu()
        }
    }

    // 🔄 GLOBAL CLEANUP LISTENER
    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== bluetoothOverlayModal && menuOpen) {
                closeMenu();
            }
        }
    }

    // ==========================================
    // 🪟 OVERLAY CONTROL MODAL WINDOW
    // ==========================================
    PanelWindow {
        id: bluetoothOverlayModal
        visible: bluetoothRoot.menuOpen
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && bluetoothRoot.menuOpen) popupMenuFrame.forceActiveFocus();
        }

        MouseArea { anchors.fill: parent; onClicked: closeMenu() }

        Rectangle {
            id: popupMenuFrame
            width: 300
            
            // 🔒 FIXED: Anchored top-left, matching the universal shell axis alignment
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 12
            
            // Explicit animation targets
            property int targetX: -655
            property real targetOpacity: 0.0

            // 🔒 FIXED: Apply your exact 5px margin specification rule to lock it flush to your bar geometry border
            anchors.leftMargin: targetX
            opacity: targetOpacity

            // ✨ ENTRY SEQUENCE: Bypasses layer initialization race conditions
            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupMenuFrame; property: "targetX"; to: 5; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupMenuFrame; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            // ✨ EXIT SLIDE IMPLICIT TRACKER
            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            
            // ✨ EXIT FADE IMPLICIT TRACKER
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            color: "#cc11111b" 
            border.color: "#898989" 
            border.width: 1
            radius: 12

            height: !bluetoothRoot.isPowered ? 92 : Math.min(100 + ((currentTab === "paired" ? pairedDevicesModel.count : discoveredDevicesModel.count) * 42), 300)

            Behavior on height {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
            
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            MouseArea {
                id: cardHoverTracker
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: checkUserActivity()
            }

            MouseArea { anchors.fill: parent; onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); } }

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
                                if (!bluetoothToggleAction.running) {
                                    bluetoothToggleAction.running = true;
                                    bluetoothRoot.isPowered = !bluetoothRoot.isPowered;
                                    if (!bluetoothRoot.isPowered) { 
                                        pairedDevicesModel.clear(); 
                                        discoveredDevicesModel.clear(); 
                                    }
                                    checkUserActivity();
                                }
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
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { bluetoothRoot.currentTab = "paired"; checkUserActivity(); } }
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
                                checkUserActivity();
                            }
                        }
                    }
                }

                // SUBSECTION SEPARATOR
                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244"; visible: bluetoothRoot.isPowered }

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
                            font.family: "Rubik"; font.pixelSize: 12; color: "#a6adc8"; 
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
                                    Text { text: model.isDeviceConnected ? "Disconnect" : "Connect"; font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold; color: model.isDeviceConnected ? "#f38ba8" : "#cdd6f4"; visible: pArea.containsMouse }
                                }
                                MouseArea {
                                    id: pArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!deviceConnectionAction.running) {
                                            const actionType = model.isDeviceConnected ? "disconnect" : "connect";
                                            deviceConnectionAction.command = ["bluetoothctl", actionType, model.macAddress];
                                            deviceConnectionAction.running = true;
                                            pairedDevicesModel.setProperty(index, "isDeviceConnected", !model.isDeviceConnected);
                                            checkUserActivity();
                                        }
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
                            font.family: "Rubik"; font.pixelSize: 12; color: "#a6adc8"; 
                            visible: discoveryListView.count === 0 || !bluetoothRoot.isPowered 
                        }
                        delegate: Item {
                            width: discoveryListView.width; height: 36
                            Rectangle {
                                anchors.fill: parent; color: dArea.containsMouse ? "#313244" : "transparent"; radius: 6
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 10
                                    Text { text: ""; font.family: "Rubik"; font.pixelSize: 14; color: "#cdd6f4" } 
                                    Text { text: model.deviceName; font.family: "Rubik"; font.pixelSize: 13; color: "#cdd6f4"; Layout.fillWidth: true; elide: Text.ElideRight } 
                                    Text { text: "Pair"; font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold; color: "#cdd6f4"; visible: dArea.containsMouse } 
                                }
                                MouseArea {
                                    id: dArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!pairAction.running) {
                                            pairAction.command = ["bash", "-c", "bluetoothctl pair " + model.macAddress + " && bluetoothctl trust " + model.macAddress + " && bluetoothctl connect " + model.macAddress];
                                            pairAction.running = true;
                                            bluetoothRoot.currentTab = "paired";
                                            checkUserActivity();
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
}
