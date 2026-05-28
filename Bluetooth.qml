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

    // 🎯 THE FIX: Resolves the local absolute path safely using standard QML URL translation
    Component.onCompleted: {
        const localUri = Qt.resolvedUrl(".").toString();
        const basePath = localUri.replace("file://", "");
        
        bluetoothWatcher.command = [basePath + "/bluetooth_control.sh", "status"];
        deviceScraper.command = [basePath + "/bluetooth_control.sh", "paired"];
        scanAction.command = ["timeout", "5s", basePath + "/bluetooth_control.sh", "scan"];
        discoveryScraper.command = [basePath + "/bluetooth_control.sh", "discover"];
        bluetoothToggleAction.command = [basePath + "/bluetooth_control.sh", "toggle"];
        
        // Safe operational bootstrap trigger
        bluetoothWatcher.running = true;
    }

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
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;

        rootScope.requestOpen(bluetoothOverlayModal);
        menuOpen = true;

        slideInAnimation.start();
        bluetoothRoot.currentTab = "paired";
        refreshPairedList();
        checkUserActivity();
    }

    function closeMenu(): void {
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;

        closeTimer.start();
    }

    // 🛠️ RELIABLE PRESENCE DETECTOR
    function checkUserActivity() {
        if (cardHoverTracker.containsMouse || pairedListView.isHoveringItems) {
            osdAutohideTimer.stop(); 
        } else if (bluetoothOverlayModal.visible && menuOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    function refreshStatus() {
        if (bluetoothWatcher.command && bluetoothWatcher.command.length > 0 && !bluetoothWatcher.running) {
            bluetoothWatcher.running = true;
        }
    }

    function refreshPairedList() {
        if (!bluetoothRoot.isPowered) return;
        if (deviceScraper.command && deviceScraper.command.length > 0 && !deviceScraper.running) {
            deviceScraper.running = true;
        }
    }

    function refreshDiscoverList() {
        if (!bluetoothRoot.isPowered) return;
        if (discoveryScraper.command && discoveryScraper.command.length > 0 && !discoveryScraper.running) {
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
        command: ["true"]
        running: false
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
        command: ["true"]
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
                            deviceName: segments[2],
                            isTransitioning: false 
                        });
                    }
                }
            }
        }
    }

    // 📡 DISCOVERY LIVE SCANNER RUNNER
    Process {
        id: scanAction
        command: ["true"]
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
        command: ["true"]
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
        id: bluetoothToggleAction
        command: ["true"]
        running: false
        onExited: { running = false; refreshStatus(); }
    }
    Process { 
        id: deviceConnectionAction 
        command: ["true"]
        running: false
        onExited: { running = false; refreshStatus(); refreshPairedList(); }
    }
    Process { 
        id: pairAction 
        command: ["true"]
        running: false
        onExited: { running = false; refreshStatus(); refreshPairedList(); }
    }
    
    // 🗑️ FORGET DEVICE PIPE
    Process {
        id: unpairAction
        command: ["true"]
        running: false
        onExited: { running = false; refreshStatus(); refreshPairedList(); }
    }

    function triggerScan() {
        if (!bluetoothRoot.isPowered || bluetoothRoot.isScanning || !scanAction.command || scanAction.command.length === 0) return;
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

    // ==========================================
    // 🎨 UI PANEL TRIGGER BUTTON
    // ==========================================
    Rectangle {
        id: triggerBox
        anchors.fill: parent
        color: bluetoothMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 0 

        Text {
            anchors.centerIn: parent
            text: bluetoothRoot.isPowered ? (bluetoothRoot.isConnected ? "󰂱" : "󰂯") : "󰂲"
            font.family: "Rubik"
            font.pixelSize: 20
            color: bluetoothRoot.isConnected ? "#ffffff" : 
                   bluetoothRoot.isPowered   ? "#ffffff" : "#59ffffff"
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
            
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 12
            
            property int targetX: -655
            property real targetOpacity: 0.0

            anchors.leftMargin: targetX
            opacity: targetOpacity

            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupMenuFrame; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupMenuFrame; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
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
            
            antialiasing: false
            topLeftRadius: 0; bottomLeftRadius: 0; topRightRadius: 0; bottomRightRadius: 0

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
                    Text { text: "Bluetooth"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#ffffff" } 
                    Item { Layout.fillWidth: true }
                    
                    Rectangle {
                        width: 50; height: 24; radius: 12
                        color: bluetoothRoot.isPowered ? "#45ffffff" : "#26ffffff"
                        
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
                        color: bluetoothRoot.currentTab === "paired" ? "#26ffffff" : "transparent"
                        Text { text: "My Devices"; font.family: "Rubik"; font.pixelSize: 12; color: "#ffffff"; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { bluetoothRoot.currentTab = "paired"; checkUserActivity(); } }
                    }

                    // Tab Button: Discover New Devices
                    Rectangle {
                        Layout.fillWidth: true; height: 26; radius: 6
                        color: bluetoothRoot.currentTab === "discover" ? "#26ffffff" : "transparent"
                        RowLayout {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "Discover"; font.family: "Rubik"; font.pixelSize: 12; color: "#ffffff" }
                            Text {
                                text: ""; font.family: "FontAwesome"
                                font.pixelSize: 10; color: "#ffffff"
                                visible: bluetoothRoot.isScanning
                                RotationAnimator on rotation { loops: Animation.Infinite; from: 0; to: 360; running: bluetoothRoot.isScanning; duration: 1000 }
                            }
                        }
                        MouseArea {
                            id: tabDiscoverMouse
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
                Rectangle { Layout.fillWidth: true; height: 1; color: "#26ffffff"; visible: bluetoothRoot.isPowered }

                // PANE MULTIPLEXER STACK
                Item {
                    id: multiplexStackContainer
                    Layout.fillWidth: true; Layout.fillHeight: true

                    // PANE 1: PAIRED LIST
                    ListView {
                        id: pairedListView
                        anchors.fill: parent; spacing: 4
                        model: pairedDevicesModel
                        visible: bluetoothRoot.currentTab === "paired" && bluetoothRoot.isPowered

                        property bool isHoveringItems: false

                        Text { 
                            anchors.centerIn: parent; 
                            text: bluetoothRoot.isPowered ? "No paired devices found" : "Bluetooth is turned off"; 
                            font.family: "Rubik"; font.pixelSize: 12; color: "#59ffffff"; 
                            visible: pairedListView.count === 0 || !bluetoothRoot.isPowered 
                        }
                        
                        delegate: Item {
                            id: delegateRoot
                            width: pairedListView.width; height: 36
                            
                            Rectangle {
                                id: rowBox
                                anchors.fill: parent; color: rowMasterArea.containsMouse ? "#26ffffff" : "transparent"; radius: 6
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: model.isTransitioning ? 82 : 122 
                                    spacing: 10
                                    
                                    Text { text: model.isDeviceConnected ? "󰂱" : "󰂯"; font.family: "Rubik"; font.pixelSize: 16; color: "#ffffff" }
                                    Text { text: model.deviceName; font.family: "Rubik"; font.pixelSize: 13; color: "#ffffff"; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                                
                                Item {
                                    id: staticOptionsWrapper
                                    width: model.isTransitioning ? 70 : 110
                                    height: parent.height
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    opacity: rowMasterArea.containsMouse ? 1.0 : 0.0
                                    z: 20 

                                    Item {
                                        id: connectButtonFrame
                                        width: actionLabel.implicitWidth
                                        height: parent.height
                                        anchors.left: parent.left

                                        Text {
                                            id: actionLabel
                                            text: model.isTransitioning ? "Connecting..." : (model.isDeviceConnected ? "Disconnect" : "Connect")
                                            font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold
                                            color: "#ffffff"
                                            anchors.centerIn: parent
                                        }
                                    }

                                    Text { 
                                        id: pipeDivider
                                        text: "|" 
                                        font.family: "Rubik"; font.pixelSize: 11; color: "#26ffffff"
                                        anchors.left: connectButtonFrame.right
                                        anchors.leftMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !model.isTransitioning
                                    }
                                    
                                    Item {
                                        id: forgetButtonFrame
                                        width: forgetLabel.implicitWidth
                                        height: parent.height
                                        anchors.left: pipeDivider.right
                                        anchors.leftMargin: 6
                                        visible: !model.isTransitioning

                                        Text {
                                            id: forgetLabel
                                            text: "Forget"
                                            font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold; color: "#59ffffff"
                                            anchors.centerIn: parent
                                        }
                                    }
                                }

                                MouseArea {
                                    id: rowMasterArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    onContainsMouseChanged: {
                                        pairedListView.isHoveringItems = rowMasterArea.containsMouse;
                                        bluetoothRoot.checkUserActivity();
                                    }

                                    cursorShape: {
                                        if (!containsMouse) return Qt.ArrowCursor;
                                        let localX = mouseX - staticOptionsWrapper.x;
                                        
                                        if (model.isTransitioning) {
                                            return (localX >= connectButtonFrame.x && localX <= (connectButtonFrame.x + connectButtonFrame.width)) ? Qt.PointingHandCursor : Qt.ArrowCursor;
                                        } else {
                                            let overConnect = (localX >= connectButtonFrame.x && localX <= (connectButtonFrame.x + connectButtonFrame.width));
                                            let overForget = (localX >= forgetButtonFrame.x && localX <= (forgetButtonFrame.x + forgetButtonFrame.width));
                                            return (overConnect || overForget) ? Qt.PointingHandCursor : Qt.ArrowCursor;
                                        }
                                    }

                                    onClicked: (mouse) => {
                                        let localX = mouseX - staticOptionsWrapper.x;
                                        let overConnect = (localX >= connectButtonFrame.x && localX <= (connectButtonFrame.x + connectButtonFrame.width));
                                        let overForget = (!model.isTransitioning && localX >= forgetButtonFrame.x && localX <= (forgetButtonFrame.x + forgetButtonFrame.width));

                                        if (overConnect && !deviceConnectionAction.running) {
                                            const actionType = model.isDeviceConnected ? "disconnect" : "connect";
                                            deviceConnectionAction.command = ["bluetoothctl", actionType, model.macAddress];
                                            deviceConnectionAction.running = true;
                                            
                                            if (!model.isDeviceConnected) {
                                                pairedDevicesModel.setProperty(index, "isTransitioning", true);
                                            } else {
                                                pairedDevicesModel.setProperty(index, "isDeviceConnected", false);
                                            }
                                            bluetoothRoot.checkUserActivity();
                                        } 
                                        else if (overForget && !unpairAction.running) {
                                            unpairAction.command = ["bluetoothctl", "remove", model.macAddress];
                                            unpairAction.running = true;
                                            bluetoothRoot.checkUserActivity();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // PANE 2: DISCOVERY LIVE LIST
                    ListView {
                        id: discoveryListView
                        anchors.fill: parent; spacing: 4
                        model: discoveredDevicesModel
                        visible: bluetoothRoot.currentTab === "discover" && bluetoothRoot.isPowered

                        Text { 
                            anchors.centerIn: parent; 
                            text: bluetoothRoot.isPowered ? (bluetoothRoot.isScanning ? "Scanning for local signals..." : "No new devices found") : "Bluetooth is turned off"; 
                            font.family: "Rubik"; font.pixelSize: 12; color: "#59ffffff"; 
                            visible: discoveryListView.count === 0 || !bluetoothRoot.isPowered 
                        }
                        
                        delegate: Item {
                            width: discoveryListView.width; height: 36
                            
                            Rectangle {
                                anchors.fill: parent; color: dArea.containsMouse ? "#26ffffff" : "transparent"; radius: 6
                                
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 8; spacing: 10
                                    
                                    Item {
                                        width: 14; height: 14
                                        Layout.alignment: Qt.AlignVCenter
                                        
                                        Rectangle { width: 10; height: 2; color: "#ffffff"; anchors.centerIn: parent }
                                        Rectangle { width: 2; height: 10; color: "#ffffff"; anchors.centerIn: parent }
                                    }
                                    
                                    Text { text: model.deviceName; font.family: "Rubik"; font.pixelSize: 13; color: "#ffffff"; Layout.fillWidth: true; elide: Text.ElideRight } 
                                    Text { text: "Pair"; font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold; color: "#ffffff"; visible: dArea.containsMouse } 
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
