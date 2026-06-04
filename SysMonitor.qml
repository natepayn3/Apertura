import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Item {
    id: monitorRoot

    implicitWidth: 32
    implicitHeight: 32

    property bool menuOpen: false

    property int cpuPercent: 0
    property int cpuTemp: 0
    property real ramUsed: 0.0
    property real ramTotal: 0.0
    property int ramPercent: 0
    
    property string diskUsed: "0"
    property string diskTotal: "0"
    property int diskPercent: 0

    // Vendor-agnostic GPU properties and presence validation flag
    property bool hasGpu: false
    property int gpuPercent: 0
    property int gpuTemp: 0

    property var theme: rootScope.theme

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

    ListModel {
        id: processListModel
    }

    Process {
        id: metricsFetcher
        command: ["sh", "-c", "raw_temp=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1); temp=$((raw_temp / 1000)); while read -r m v _; do case \"$m\" in MemTotal:) t=$v ;; MemAvailable:) a=$v ;; esac; done < /proc/meminfo; read -r _ u n s i iw irq sof _ < /proc/stat; total=$((u + n + s + i + iw + irq + sof)); idle=$((i + iw)); df_out=$(df -h / | tail -n 1 | awk '{ u_val=$3; t_val=$2; sub(/[GGMK]/,\"\",u_val); sub(/[GGMK]/,\"\",t_val); print u_val\" \"t_val\" \"$5}'); g_busy=\"none\"; g_temp=0; if command -v nvidia-smi >/dev/null 2>&1; then nv_out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null); g_busy=$(echo \"$nv_out\" | awk -F', ' '{print $1}'); g_temp=$(echo \"$nv_out\" | awk -F', ' '{print $2}'); else for card in /sys/class/drm/card*/device; do if [ -f \"$card/gpu_busy_percent\" ]; then cur_b=$(cat \"$card/gpu_busy_percent\" 2>/dev/null); if [ \"$g_busy\" = \"none\" ] || [ \"$cur_b\" -gt \"$g_busy\" ]; then g_busy=$cur_b; fi; hw_t=$(cat $card/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1); [ ! -z \"$hw_t\" ] && g_temp=$((hw_t / 1000)); fi; done; fi; echo \"$total $idle $temp $a $t $df_out $g_busy $g_temp\""]
        running: false

        stdout: StdioCollector {
            property int prevTotal: 0
            property int prevIdle: 0

            onTextChanged: {
                let cleaned = text.trim();
                if (!cleaned) return;
                let parts = cleaned.split(/\s+/); 
                if (parts.length < 10) return; 

                let curTotal = parseInt(parts[0]);
                let curIdle = parseInt(parts[1]);

                if (prevTotal !== 0) {
                    let diffTotal = curTotal - prevTotal;
                    let diffIdle = curIdle - prevIdle;
                    if (diffTotal > 0) {
                        monitorRoot.cpuPercent = Math.round(((diffTotal - diffIdle) / diffTotal) * 100);
                    }
                }
                prevTotal = curTotal;
                prevIdle = curIdle;

                monitorRoot.cpuTemp = parseInt(parts[2]);
                let availMem = parseFloat(parts[3]);
                let totalMem = parseFloat(parts[4]);

                monitorRoot.ramTotal = totalMem / 1024 / 1024;
                monitorRoot.ramUsed = (totalMem - availMem) / 1024 / 1024;
                monitorRoot.ramPercent = Math.round(((totalMem - availMem) / totalMem) * 100);
                
                monitorRoot.diskUsed = parts[5];
                monitorRoot.diskTotal = parts[6];
                monitorRoot.diskPercent = parseInt(parts[7].replace("%", ""));

                // Evaluate if a functional hardware controller layer was detected
                if (parts[8] === "none") {
                    monitorRoot.hasGpu = false;
                    monitorRoot.gpuPercent = 0;
                    monitorRoot.gpuTemp = 0;
                } else {
                    monitorRoot.hasGpu = true;
                    monitorRoot.gpuPercent = Math.min(Math.max(parseInt(parts[8]), 0), 100);
                    monitorRoot.gpuTemp = Math.max(parseInt(parts[9]), 0);
                }
            }
        }
    }

    Process {
        id: taskListFetcher
        command: ["sh", "-c", "threads=$(nproc); ps -eo comm,pcpu --sort=-pcpu | awk -v t=\"$threads\" 'NR>1 {print $1, $2/t}'"]
        running: false

        stdout: StdioCollector {
            onTextChanged: {
                let cleaned = text.trim();
                if (!cleaned) return;

                let lines = cleaned.split("\n");
                processListModel.clear();

                let maxLines = Math.min(lines.length, 7); 

                for (let i = 0; i < maxLines; i++) {
                    let line = lines[i].trim();
                    if (!line) continue;

                    let lastSpace = line.lastIndexOf(" ");
                    if (lastSpace === -1) continue;

                    let pName = line.substring(0, lastSpace).trim();
                    let pCpuRaw = parseFloat(line.substring(lastSpace + 1).trim());

                    if (pName === "ps" || pName === "sh" || pName === "awk" || pName === "quickshell") continue;

                    if (pName && !isNaN(pCpuRaw)) {
                        let pCpuNormalized = pCpuRaw.toFixed(1);
                        processListModel.append({ "name": pName, "cpu": pCpuNormalized });
                    }
                }
            }
        }
    }

    Timer {
        id: metricsTicker
        interval: 1000
        running: drawerTemplate.isOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            metricsFetcher.running = false;
            metricsFetcher.running = true;
            taskListFetcher.running = false;
            taskListFetcher.running = true;
        }
    }

    Rectangle {
        id: sysMonitorHitbox
        anchors.fill: parent
        color: "transparent"
        radius: 0

        Text {
            anchors.centerIn: parent
            text: "cardiology"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff"
        }

        Rectangle {
            id: sysHoverOverlay
            anchors.fill: parent
            radius: 0
            color: monitorRoot.theme ? monitorRoot.theme.theme_primary : "#89b4fa"
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
        drawerHeight: monitorRoot.hasGpu ? 375 : 330 // Dynamically shrink card baseline height if GPU layout drops
        modalToken: "sysmonitor"
        anchorTop: false

        onIsOpenChanged: {
            if (isOpen) {
                monitorRoot.menuOpen = true;
                checkUserActivity();
                mainContainerLayout.forceActiveFocus();
            } else {
                monitorRoot.menuOpen = false;
            }
        }

        MouseArea {
            id: cardHoverTracker
            anchors.fill: parent
            hoverEnabled: true
            onContainsMouseChanged: checkUserActivity()
        }

        MouseArea {
            id: preventDismiss
            anchors.fill: parent
            onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
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
                    id: titleLabel
                    text: "Usage"
                    font.family: "Rubik"
                    font.pixelSize: 16
                    font.weight: Font.Bold 
                    color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    x: 2
                }
            }

            Rectangle {
                id: headerDivider
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: monitorRoot.theme ? monitorRoot.theme.theme_outline : "#26ffffff"
                Layout.bottomMargin: 8
            }

            ColumnLayout {
                id: metricsBlock
                Layout.fillWidth: true
                spacing: 8 

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "CPU"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium; color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff" }
                        Item { Layout.fillWidth: true }
                        Text { text: monitorRoot.cpuTemp + "°C  |  " + monitorRoot.cpuPercent + "%"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff" }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4

                        Rectangle {
                            anchors.fill: parent
                            color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff"
                            opacity: 0.12
                            radius: 0
                        }

                        Rectangle {
                            id: cpuProgressBar
                            height: parent.height
                            width: parent.width * (monitorRoot.cpuPercent / 100.0)
                            color: monitorRoot.theme ? monitorRoot.theme.theme_primary : "#ffffff"
                            radius: 0
                            
                            Behavior on width { 
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic } 
                            }
                        }
                    }
                }

                ColumnLayout {
                    id: gpuLayoutGroup
                    Layout.fillWidth: true
                    spacing: monitorRoot.hasGpu ? 3 : 0
                    
                    // Collapse height properties down to zero cleanly to free space when inactive
                    visible: monitorRoot.hasGpu
                    Layout.preferredWidth: monitorRoot.hasGpu ? -1 : 0
                    Layout.preferredHeight: monitorRoot.hasGpu ? -1 : 0

                    RowLayout {
                        Layout.fillWidth: true
                        visible: monitorRoot.hasGpu
                        Text { text: "GPU"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium; color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff" }
                        Item { Layout.fillWidth: true }
                        Text { text: monitorRoot.gpuTemp + "°C  |  " + monitorRoot.gpuPercent + "%"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff" }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: monitorRoot.hasGpu ? 4 : 0
                        visible: monitorRoot.hasGpu

                        Rectangle {
                            anchors.fill: parent
                            color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff"
                            opacity: 0.12
                            radius: 0
                        }

                        Rectangle {
                            id: gpuProgressBar
                            height: parent.height
                            width: parent.width * (monitorRoot.gpuPercent / 100.0)
                            color: monitorRoot.theme ? monitorRoot.theme.theme_primary : "#ffffff"
                            radius: 0
                            
                            Behavior on width { 
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic } 
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "RAM"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium; color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff" }
                        Item { Layout.fillWidth: true }
                        Text { text: monitorRoot.ramUsed.toFixed(1) + " / " + monitorRoot.ramTotal.toFixed(1) + " GB"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff" }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4

                        Rectangle {
                            anchors.fill: parent
                            color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff"
                            opacity: 0.12
                            radius: 0
                        }

                        Rectangle {
                            id: ramProgressBar
                            height: parent.height
                            width: parent.width * (monitorRoot.ramPercent / 100.0)
                            color: monitorRoot.theme ? monitorRoot.theme.theme_primary : "#ffffff"
                            radius: 0
                            
                            Behavior on width { 
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic } 
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Disk Usage"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium; color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff" }
                        Item { Layout.fillWidth: true }
                        Text { text: monitorRoot.diskUsed + " / " + monitorRoot.diskTotal + " GB"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff" }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4

                        Rectangle {
                            anchors.fill: parent
                            color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff"
                            opacity: 0.12
                            radius: 0
                        }

                        Rectangle {
                            id: diskProgressBar
                            height: parent.height
                            width: parent.width * (monitorRoot.diskPercent / 100.0)
                            color: monitorRoot.theme ? monitorRoot.theme.theme_primary : "#ffffff"
                            radius: 0
                            
                            Behavior on width { 
                                NumberAnimation { duration: 180; easing.type: Easing.OutCubic } 
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: listDivider
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: monitorRoot.theme ? monitorRoot.theme.theme_outline : "#26ffffff"
                Layout.topMargin: 12
                Layout.bottomMargin: 8
            }

            Text {
                id: tasksHeaderLabel
                text: "Processes"
                font.family: "Rubik"
                font.pixelSize: 13
                font.weight: Font.Bold
                color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff"
                Layout.bottomMargin: 6
            }

            Item {
                id: listBoundsFrame
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: processListView
                    anchors.fill: parent
                    model: processListModel
                    spacing: 4
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: processListView.width
                        height: 24
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4

                            Text {
                                text: model.name
                                font.family: "Rubik"
                                font.pixelSize: 11
                                color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#59ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.cpu + "%"
                                font.family: "Rubik"
                                font.pixelSize: 11
                                font.weight: Font.Medium
                                color: monitorRoot.theme ? monitorRoot.theme.theme_fg : "#ffffff"
                            }
                        }
                    }
                }
            }
        }
    }
}
