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
    
    // Internal property to track previous state and prevent notification loops
    property bool _wasVpnActive: false

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

    // Process to handle firing notifications via notify-send
    Process {
        id: notifier
        running: false
    }

    function sendNotification(title, message, icon) {
        notifier.command = ["notify-send", "-a", "VPN Manager", "-i", icon, title, message];
        notifier.running = true;
    }

    Process {
        id: vpnScanner
        command: ["nmcli", "-g", "TYPE,NAME,STATE", "connection", "show", "--active"]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    let cleanText = text.trim();
                    let lines = cleanText.split("\n");
                    
                    let foundActive = false;

                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i].trim();
                        if (line.startsWith("wireguard:") || line.startsWith("vpn:") || line.startsWith("tun:")) {
                            let parts = line.split(":");
                            if (parts.length >= 3 && parts[2] === "activated") {
                                vpnRoot.detectedConnection = parts[1];
                                vpnRoot.isVpnActive = true;
                                foundActive = true;
                                break;
                            }
                        }
                    }

                    if (!foundActive) {
                        vpnRoot.detectedConnection = "";
                        vpnRoot.isVpnActive = false;
                    }

                    // Check for state mutations to fire notifications
                    if (vpnRoot.isVpnActive !== vpnRoot._wasVpnActive) {
                        if (vpnRoot.isVpnActive) {
                            vpnRoot.sendNotification(
                                "VPN Connected", 
                                "Secure tunnel established to " + vpnRoot.detectedConnection, 
                                "network-vpn"
                            );
                        } else {
                            vpnRoot.sendNotification(
                                "VPN Disconnected", 
                                "The secure tunnel connection has been closed.", 
                                "network-vpn-disabled"
                            );
                        }
                        // Update the sync checkpoint state
                        vpnRoot._wasVpnActive = vpnRoot.isVpnActive;
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