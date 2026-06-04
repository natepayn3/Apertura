import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Item {
    id: netRoot
    implicitWidth: 32
    implicitHeight: 32

    property bool menuOpen: false

    property string activeIface: "None"
    property string ipAddress: "0.0.0.0"
    property string downloadSpeed: "0 B/s"
    property string uploadSpeed: "0 B/s"
    
    property string connectionIcon: activeIface === "None" ? "cloud_off" : "cloud_upload"

    Timer {
        id: osdAutohideTimer
        interval: Config.autohideInterval
        running: false
        repeat: false
        onTriggered: closeMenu()
    }

    function toggleMenu(): void {
        drawerTemplate.isOpen = !drawerTemplate.isOpen;
    }

    function closeMenu(): void {
        drawerTemplate.isOpen = false;
    }

    function checkUserActivity() {
        if (cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop();
        } else if (drawerTemplate.isOpen) {
            osdAutohideTimer.restart();
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                closeMenu();
            }
        }
    }

    Process {
        id: netFetcher
        command: [
            "sh", "-c",
            "iface=$(ip route show | awk '$1 == \"default\" {print $5; exit}'); " +
            "if [ -z '$iface' ]; then iface=$(ip -4 link show up | awk -F': ' '$2 != \"lo\" {print $2; exit}'); fi; " +
            "if [ -n '$iface' ]; then " +
            "  ip_addr=$(ip -4 addr show dev \"$iface\" | awk '$1 == \"inet\" {split($2, a, \"/\"); print a[1]; exit}'); " +
            "  stats=$(awk -v d=\"$iface\" '{gsub(/[: \t]+/, \" \"); if ($1 == d) print $2\" \"$10}' /proc/net/dev); " +
            "  echo \"$iface $ip_addr $stats\"; " +
            "else " +
            "  echo 'None 0.0.0.0 0 0'; " +
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
        color: "transparent"
        radius: 0

        Text {
            anchors.centerIn: parent
            text: netRoot.connectionIcon
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: activeIface === "None" ? "#ff5555" : (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff")
        }

        Rectangle {
            id: netHoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: iconMouseArea.containsMouse ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: iconMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 180
        modalToken: "netmonitor"
        anchorTop: false

        onIsOpenChanged: {
            if (isOpen) {
                netRoot.menuOpen = true;
                checkUserActivity();
                mainContainerLayout.forceActiveFocus();
            } else {
                netRoot.menuOpen = false;
            }
        }

        MouseArea {
            id: cardHoverTracker
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: checkUserActivity()
        }

        ColumnLayout {
            id: mainContainerLayout
            anchors.fill: parent
            anchors.margins: 12
            spacing: 0
            focus: true

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 32

                Text {
                    text: "Network Status"
                    font.family: "Rubik"
                    font.pixelSize: 16
                    font.weight: Font.Bold
                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    x: 2
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                Layout.bottomMargin: 12
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        Text { text: "Interface"; font.family: "Rubik"; font.pixelSize: 11; color: rootScope.theme ? Qt.alpha(rootScope.theme.theme_fg, 0.35) : "#59ffffff" }
                        Text { text: netRoot.activeIface; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff" }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 2; Layout.alignment: Qt.AlignRight
                        Text { text: "IP Address"; font.family: "Rubik"; font.pixelSize: 11; color: rootScope.theme ? Qt.alpha(rootScope.theme.theme_fg, 0.35) : "#59ffffff" }
                        Text { text: netRoot.ipAddress; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"; Layout.alignment: Qt.AlignRight }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: rootScope.theme ? Qt.alpha(rootScope.theme.theme_outline, 0.5) : "#1affffff" }

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        Text { text: "Download"; font.family: "Rubik"; font.pixelSize: 11; color: rootScope.theme ? Qt.alpha(rootScope.theme.theme_fg, 0.35) : "#59ffffff" }
                        RowLayout {
                            spacing: 6
                            Text { text: "arrow_downward"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff" }
                            Text { text: netRoot.downloadSpeed; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        spacing: 2; Layout.alignment: Qt.AlignRight
                        Text { text: "Upload"; font.family: "Rubik"; font.pixelSize: 11; color: rootScope.theme ? Qt.alpha(rootScope.theme.theme_fg, 0.35) : "#59ffffff" }
                        RowLayout {
                            spacing: 6; Layout.alignment: Qt.AlignRight
                            Text { text: "arrow_upward"; font.family: "Material Symbols Outlined"; font.pixelSize: 16; color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff" }
                            Text { text: netRoot.uploadSpeed; font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"; Layout.alignment: Qt.AlignRight }
                        }
                    }
                }
            }
        }
    }
}
