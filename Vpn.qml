import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: vpnRoot
    width: 32
    height: 32

    property string detectedConnection: ""
    property bool isVpnActive: false

    Timer {
        id: syncVpnTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: {
            vpnScanner.running = false;
            vpnScanner.running = true;
        }
    }

    Process {
        id: vpnScanner
        command: ["nmcli", "-g", "TYPE,NAME,STATE", "connection", "show", "--active"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let cleanText = text.trim();
                    if (!cleanText) {
                        vpnRoot.detectedConnection = "";
                        vpnRoot.isVpnActive = false;
                        return;
                    }

                    let lines = cleanText.split("\n");
                    let foundActive = false;
                    let parsedConnection = "";

                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i].trim();
                        if (line.startsWith("wireguard:") || line.startsWith("vpn:") || line.startsWith("tun:")) {
                            let parts = line.split(":");
                            if (parts.length >= 3 && parts[2] === "activated") {
                                parsedConnection = parts[1];
                                foundActive = true;
                                break;
                            }
                        }
                    }

                    if (foundActive) {
                        vpnRoot.detectedConnection = parsedConnection;
                        vpnRoot.isVpnActive = true;
                    } else {
                        vpnRoot.detectedConnection = "";
                        vpnRoot.isVpnActive = false;
                    }

                } catch(e) {
                    vpnRoot.detectedConnection = "";
                    vpnRoot.isVpnActive = false;
                }
            }
        }
    }

    Process {
        id: vpnToggler
        running: false
        onExited: (code) => {
            vpnScanner.running = false;
            vpnScanner.running = true;
        }
    }

    function toggleVpnState() {
        const localUri = Qt.resolvedUrl(".").toString();
        const basePath = localUri.replace("file://", "");
        let scriptPath = basePath + "/Scripts/vpn-toggle.sh";
        
        vpnToggler.command = [scriptPath, vpnRoot.isVpnActive.toString(), vpnRoot.detectedConnection];
        vpnToggler.running = true;
    }

    Rectangle {
        id: volumeHitbox
        anchors.fill: parent
        color: "transparent"
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                id: volumeIcon
                Layout.alignment: Qt.AlignHCenter
                text: vpnRoot.isVpnActive ? "vpn_key" : "vpn_key_off"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
            }
        }

        Rectangle {
            id: audioHoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: volumeMouseArea.containsMouse ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: volumeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: vpnRoot.toggleVpnState()
        }
    }
}
