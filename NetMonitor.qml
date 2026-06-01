import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: netRoot
    implicitWidth: 32
    implicitHeight: 32

    property bool menuOpen: false
    property bool windowAlive: false

    property string activeIface: "None"
    property string ipAddress: "0.0.0.0"
    property string downloadSpeed: "0 B/s"
    property string uploadSpeed: "0 B/s"
    
    property string connectionIcon: activeIface === "None" ? "cloud_off" : "cloud_upload"

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
        windowAlive = true;
        rootScope.requestOpen(netOverlayModal);
        menuOpen = true;
        checkUserActivity();
    }

    function closeMenu(): void {
        menuOpen = false;
    }

    function checkUserActivity() {
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop();
        } else {
            osdAutohideTimer.restart();
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== netOverlayModal && menuOpen) {
                closeMenu();
            }
        }
    }

    Process {
        id: netFetcher
        command: [
            "sh", "-c",
            "iface=$(/usr/bin/ip -j addr | /usr/bin/jq -r '.[] | select(.ifname != \"lo\" and .addr_info[].family == \"inet\") | .ifname' | /usr/bin/head -n1); " +
            "if [ -n \"$iface\" ]; then " +
            "  ip_addr=$(/usr/bin/ip -j addr show dev \"$iface\" | /usr/bin/jq -r '.[].addr_info[] | select(.family == \"inet\") | .local'); " +
            "  stats=$(/usr/bin/grep \"$iface:\" /proc/net/dev | /usr/bin/awk '{print $2\" \"$10}'); " +
            "  echo \"$iface $ip_addr $stats\"; " +
            "else " +
            "  echo \"None 0.0.0.0 0 0\"; " +
            "fi"
        ]
        running: false

        stdout: StdioCollector {
            property var prevRx: 0
            property var prevTx: 0

            onTextChanged: {
                let cleaned = text.trim();
                if (!cleaned) return;
                let parts = cleaned.split(" ");
                if (parts.length < 4) return;

                netRoot.activeIface = parts[0];
                netRoot.ipAddress = parts[1];

                let curRx = parseInt(parts[2]);
                let curTx = parseInt(parts[3]);

                if (prevRx !== 0 && curRx >= prevRx) {
                    netRoot.downloadSpeed = formatBytes(curRx - prevRx);
                    netRoot.uploadSpeed = formatBytes(curTx - prevTx);
                }

                prevRx = curRx;
                prevTx = curTx;
            }

            function formatBytes(bytes) {
                if (bytes === 0) return "0 B/s";
                let k = 1024;
                let sizes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
                let i = Math.floor(Math.log(bytes) / Math.log(k));
                return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
            }
        }
    }

    Timer {
        id: netTicker
        interval: 3000
        running: true  
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netFetcher.running = false;
            netFetcher.running = true;
        }
    }

    Component.onCompleted: {
        netFetcher.running = true;
    }

    Rectangle {
        id: netHitbox
        anchors.fill: parent
        color: iconMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 0

        Text {
            anchors.centerIn: parent
            text: netRoot.connectionIcon
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            // Red alert color if offline
            color: activeIface === "None" ? "#ff5555" : "#ffffff"
        }

        MouseArea {
            id: iconMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: netOverlayModal
        visible: netRoot.windowAlive
        color: "transparent"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        MouseArea { anchors.fill: parent; onClicked: closeMenu() }

        Rectangle {
            id: popupCard
            width: 300
            height: 180
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            color: "#9911111b"

            states: [
                State {
                    name: "visible"; when: netRoot.menuOpen
                    PropertyChanges { target: popupCard; x: 0; opacity: 1.0 }
                },
                State {
                    name: "hidden"; when: !netRoot.menuOpen
                    PropertyChanges { target: popupCard; x: -320; opacity: 0.0 }
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
                        ScriptAction { script: { netRoot.windowAlive = false; } }
                    }
                }
            ]

            MouseArea {
                id: cardHoverTracker; anchors.fill: parent; hoverEnabled: true
                onContainsMouseChanged: checkUserActivity()
            }

            Text {
                text: "Network Status"
                font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold
                color: "#ffffff"; x: 14; y: 14
            }

            Rectangle { width: parent.width - 24; height: 1; color: "#26ffffff"; x: 12; y: 44 }

            ColumnLayout {
                x: 14; y: 56; width: parent.width - 28; spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        Text { text: "Interface"; font.family: "Rubik"; font.pixelSize: 11; color: "#59ffffff" }
                        Text { text: netRoot.activeIface; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#ffffff" }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 2; Layout.alignment: Qt.AlignRight
                        Text { text: "IP Address"; font.family: "Rubik"; font.pixelSize: 11; color: "#59ffffff" }
                        Text { text: netRoot.ipAddress; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#ffffff"; Layout.alignment: Qt.AlignRight }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#1affffff" }

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        Text { text: "Download"; font.family: "Rubik"; font.pixelSize: 11; color: "#59ffffff" }
                        RowLayout {
                            spacing: 6
                            Text { text: "arrow_downward"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: "#ffffff" }
                            Text { text: netRoot.downloadSpeed; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#ffffff" }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 2; Layout.alignment: Qt.AlignRight
                        Text { text: "Upload"; font.family: "Rubik"; font.pixelSize: 11; color: "#59ffffff" }
                        RowLayout {
                            spacing: 6; Layout.alignment: Qt.AlignRight
                            Text { text: "arrow_upward"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: "#ffffff" }
                            Text { text: netRoot.uploadSpeed; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#ffffff" }
                        }
                    }
                }
            }
        }
    }
}
