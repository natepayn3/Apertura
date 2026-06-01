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
    property bool menuOpen: false
    property bool windowAlive: false

    ListModel { id: pairedDevicesModel }
    ListModel { id: discoveredDevicesModel }

    Component.onCompleted: {
        const localUri = Qt.resolvedUrl(".").toString();
        const basePath = localUri.replace("file://", "");
        
        bluetoothWatcher.command = [basePath + "/bluetooth_control.sh", "status"];
        deviceScraper.command = [basePath + "/bluetooth_control.sh", "paired"];
        scanAction.command = ["timeout", "5s", basePath + "/bluetooth_control.sh", "scan"];
        discoveryScraper.command = [basePath + "/bluetooth_control.sh", "discover"];
        bluetoothToggleAction.command = [basePath + "/bluetooth_control.sh", "toggle"];
        
        bluetoothWatcher.running = true;
    }

    Timer {
        id: osdAutohideTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        rootScope.requestOpen(bluetoothOverlayModal);
        windowAlive = true;
        menuOpen = true;

        bluetoothRoot.currentTab = "paired";
        refreshPairedList();
        checkUserActivity();
    }

    function closeMenu(): void {
        menuOpen = false;
    }

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
                            macAddress: segments[0].trim().toLowerCase(),
                            isDeviceConnected: segments[1].trim() === "true",
                            deviceName: segments[2].trim(),
                            isTransitioning: false 
                        });
                    }
                }
            }
        }
    }

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
                
                const pairedMacSet = new Set();
                for (let j = 0; j < pairedDevicesModel.count; j++) {
                    pairedMacSet.add(pairedDevicesModel.get(j).macAddress.toLowerCase());
                }

                discoveredDevicesModel.clear();
                
                for (let i = 0; i < lines.length; i++) {
                    const segments = lines[i].split("|");
                    if (segments.length >= 2 && segments[1].trim() !== "") {
                        const targetMac = segments[0].trim().toLowerCase();
                        
                        if (pairedMacSet.has(targetMac)) {
                            continue;
                        }

                        discoveredDevicesModel.append({
                            macAddress: targetMac,
                            deviceName: segments[1].trim()
                        });
                    }
                }
            }
        }
    }

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
        onExited: { 
            running = false; 
            refreshStatus(); 
            refreshPairedList(); 
        }
    }
    Process { 
        id: pairAction 
        command: ["true"]
        running: false
        onExited: { running = false; refreshStatus(); refreshPairedList(); }
    }
    
    Process {
        id: unpairAction
        command: ["true"]
        running: false
        onExited: { 
            running = false; 
            Qt.callLater(() => {
                refreshStatus(); 
                refreshPairedList(); 
            });
        }
    }

    function triggerScan() {
        if (!bluetoothRoot.isPowered || bluetoothRoot.isScanning || !scanAction.command || scanAction.command.length === 0) return;
        bluetoothRoot.isScanning = true;
        scanAction.running = true;
    }

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

    Timer {
        interval: 5000
        running: !bluetoothOverlayModal.visible
        repeat: true
        onTriggered: refreshStatus()
    }

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

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== bluetoothOverlayModal && menuOpen) {
                closeMenu();
            }
        }
    }

    PanelWindow {
        id: bluetoothOverlayModal
        visible: bluetoothRoot.windowAlive
        color: "transparent"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
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
            anchors.bottomMargin: 12

            states: [
                State {
                    name: "visible"
                    when: bluetoothRoot.menuOpen
                    PropertyChanges { target: popupMenuFrame; x: 0; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: !bluetoothRoot.menuOpen
                    PropertyChanges { target: popupMenuFrame; x: -320; opacity: 0.0 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "visible"
                    ParallelAnimation {
                        NumberAnimation { property: "x"; duration: 350; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.OutCubic }
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { property: "x"; duration: 350; easing.type: Easing.InCubic }
                            NumberAnimation { property: "opacity"; duration: 350; easing.type: Easing.InCubic }
                        }
                        ScriptAction {
                            script: { bluetoothRoot.windowAlive = false; }
                        }
                    }
                }
            ]

            color: "#9911111b" 
            border.width: 0
            antialiasing: false
            topLeftRadius: 0; bottomLeftRadius: 0; topRightRadius: 0; bottomRightRadius: 0

            height: {
                if (!bluetoothRoot.isPowered) return 92;
                const activeCount = (currentTab === "paired") ? pairedDevicesModel.count : discoveredDevicesModel.count;
                const baseHeight = 100 + (activeCount * 40);
                return Math.min(activeCount === 0 ? baseHeight + 40 : baseHeight, 300);
            }

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

                RowLayout {
                    Layout.fillWidth: true; spacing: 4
                    visible: bluetoothRoot.isPowered

                    Rectangle {
                        Layout.fillWidth: true; height: 26; radius: 6
                        color: bluetoothRoot.currentTab === "paired" ? "#26ffffff" : "transparent"
                        Text { text: "My Devices"; font.family: "Rubik"; font.pixelSize: 12; color: "#ffffff"; anchors.centerIn: parent }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { bluetoothRoot.currentTab = "paired"; checkUserActivity(); } }
                    }

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

                Rectangle { Layout.fillWidth: true; height: 1; color: "#26ffffff"; visible: bluetoothRoot.isPowered }

                Item {
                    id: multiplexStackContainer
                    Layout.fillWidth: true; Layout.fillHeight: true

                    ListView {
                        id: pairedListView
                        anchors.fill: parent; spacing: 4; clip: true
                        model: pairedDevicesModel
                        visible: bluetoothRoot.currentTab === "paired" && bluetoothRoot.isPowered

                        property bool isHoveringItems: false

                        Text { 
                            anchors.centerIn: parent; 
                            text: bluetoothRoot.isPowered ? "No devices paired" : "Bluetooth is turned off"; 
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
                                    anchors.rightMargin: staticOptionsWrapper.width + 12
                                    spacing: 10
                                    
                                    Text { text: model.isDeviceConnected ? "󰂱" : "󰂯"; font.family: "Rubik"; font.pixelSize: 16; color: "#ffffff"; Layout.alignment: Qt.AlignVCenter }
                                    Text { text: model.deviceName; font.family: "Rubik"; font.pixelSize: 13; color: "#ffffff"; Layout.fillWidth: true; elide: Text.ElideRight; Layout.alignment: Qt.AlignVCenter }
                                }
                                
                                RowLayout {
                                    id: staticOptionsWrapper
                                    height: parent.height
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    spacing: 8
                                    opacity: rowMasterArea.containsMouse || model.isTransitioning ? 1.0 : 0.0
                                    z: 20 

                                    Text {
                                        id: actionLabel
                                        text: model.isTransitioning ? "Connecting..." : (model.isDeviceConnected ? "Disconnect" : "Connect")
                                        font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold
                                        color: "#ffffff"
                                        Layout.alignment: Qt.AlignVCenter

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!deviceConnectionAction.running) {
                                                    if (!model.isDeviceConnected) {
                                                        pairedDevicesModel.setProperty(index, "isTransitioning", true);
                                                        deviceConnectionAction.command = ["bash", "-c", "bluetoothctl trust " + model.macAddress + " && bluetoothctl connect " + model.macAddress];
                                                    } else {
                                                        pairedDevicesModel.setProperty(index, "isDeviceConnected", false);
                                                        deviceConnectionAction.command = ["bash", "-c", "bluetoothctl disconnect " + model.macAddress];
                                                    }
                                                    deviceConnectionAction.running = true;
                                                    bluetoothRoot.checkUserActivity();
                                                }
                                            }
                                        }
                                    }

                                    Text { 
                                        id: pipeDivider
                                        text: "|" 
                                        font.family: "Rubik"; font.pixelSize: 11; color: "#26ffffff"
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: !model.isTransitioning
                                    }
                                    
                                    Text {
                                        id: forgetLabel
                                        text: "Forget"
                                        font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Bold; color: "#59ffffff"
                                        Layout.alignment: Qt.AlignVCenter
                                        visible: !model.isTransitioning

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!unpairAction.running) {
                                                    unpairAction.command = ["bash", "-c", "bluetoothctl remove " + model.macAddress];
                                                    unpairAction.running = true;
                                                    bluetoothRoot.checkUserActivity();
                                                }
                                            }
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
                                }
                            }
                        }
                    }

                    ListView {
                        id: discoveryListView
                        anchors.fill: parent; spacing: 4; clip: true 
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
