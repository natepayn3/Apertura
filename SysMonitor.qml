import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Item {
    id: monitorRoot

    implicitWidth: 32
    implicitHeight: 32

    property bool menuOpen: false
    property bool windowAlive: false

    property int cpuPercent: 0
    property int cpuTemp: 0
    property real ramUsed: 0.0
    property real ramTotal: 0.0
    property int ramPercent: 0
    
    property string diskUsed: "0"
    property string diskTotal: "0"
    property int diskPercent: 0

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
        rootScope.requestOpen(monitorOverlayModal);
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
            if (rootScope.activeModal !== monitorOverlayModal && menuOpen) {
                closeMenu();
            }
        }
    }

    ListModel {
        id: processListModel
    }

    Process {
        id: metricsFetcher
        command: ["sh", "-c", "raw_temp=$(cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1); temp=$((raw_temp / 1000)); while read -r m v _; do case \"$m\" in MemTotal:) t=$v ;; MemAvailable:) a=$v ;; esac; done < /proc/meminfo; read -r _ u n s i iw irq sof _ < /proc/stat; total=$((u + n + s + i + iw + irq + sof)); idle=$((i + iw)); df_out=$(df -h / | tail -n 1 | awk '{ u_val=$3; t_val=$2; sub(/[GGMK]/,\"\",u_val); sub(/[GGMK]/,\"\",t_val); print u_val\" \"t_val\" \"$5}'); echo \"$total $idle $temp $a $t $df_out\""]
        running: false

        stdout: StdioCollector {
            property int prevTotal: 0
            property int prevIdle: 0

            onTextChanged: {
                let cleaned = text.trim();
                if (!cleaned) return;
                let parts = cleaned.split(" ");
                if (parts.length < 8) return;

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
            }
        }
    }

    Process {
        id: taskListFetcher
        command: ["ps", "-eo", "comm,pcpu", "--sort=-pcpu"]
        running: false

        stdout: StdioCollector {
            onTextChanged: {
                let cleaned = text.trim();
                if (!cleaned) return;

                let lines = cleaned.split("\n");
                processListModel.clear();

                for (let i = 1; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (!line) continue;

                    let lastSpace = line.lastIndexOf(" ");
                    if (lastSpace === -1) continue;

                    let pName = line.substring(0, lastSpace).trim();
                    let pCpu = line.substring(lastSpace + 1).trim();

                    if (pName === "ps" || pName === "sh" || pName === "awk" || pName === "quickshell") continue;

                    if (pName && pCpu) {
                        processListModel.append({ "name": pName, "cpu": pCpu });
                    }
                }
            }
        }
    }

    Timer {
        id: metricsTicker
        interval: 1000
        running: monitorRoot.windowAlive
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
        color: iconMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 0

        Text {
            anchors.centerIn: parent
            text: "cardiology"
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: "#ffffff"
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
        id: monitorOverlayModal
        visible: monitorRoot.windowAlive
        color: "transparent"
        
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && monitorRoot.menuOpen) {
                popupCard.forceActiveFocus();
            }
        }

        MouseArea { 
            anchors.fill: parent
            onClicked: closeMenu() 
        }

        Rectangle {
            id: popupCard
            width: 300
            height: 340
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12

            states: [
                State {
                    name: "visible"
                    when: monitorRoot.menuOpen
                    PropertyChanges { target: popupCard; x: 0; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: !monitorRoot.menuOpen
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
                        ScriptAction {
                            script: { monitorRoot.windowAlive = false; }
                        }
                    }
                }
            ]

            color: "#9911111b" 
            border.width: 0
            topLeftRadius: 0
            bottomLeftRadius: 0
            topRightRadius: 0
            bottomRightRadius: 0
            focus: true
            
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            Component.onCompleted: popupCard.forceActiveFocus()

            MouseArea {
                id: cardHoverTracker
                anchors.fill: parent
                hoverEnabled: true
                onContainsMouseChanged: checkUserActivity()
            }

            MouseArea {
                anchors.fill: parent
                onPressed: (mouse) => { mouse.accepted = true; checkUserActivity(); }
            }

            Text {
                id: titleLabel
                text: "Usage"
                font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold 
                color: "#ffffff" 
                x: 14; y: 14
            }

            Rectangle {
                id: headerDivider
                width: parent.width - 24; height: 1; color: "#26ffffff"
                x: 12; y: 44
            }

            ColumnLayout {
                id: metricsBlock
                x: 14; y: 52
                width: parent.width - 28
                spacing: 8 

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "CPU"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium; color: "#ffffff" }
                        Item { Layout.fillWidth: true }
                        Text { text: monitorRoot.cpuTemp + "°C  |  " + monitorRoot.cpuPercent + "%"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: "#ffffff" }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 4; color: "#26ffffff"; radius: 0; clip: true
                        Rectangle {
                            width: parent.width * (monitorRoot.cpuPercent / 100.0)
                            height: parent.height; color: "#ffffff"; radius: 0
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "RAM"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium; color: "#ffffff" }
                        Item { Layout.fillWidth: true }
                        Text { text: monitorRoot.ramUsed.toFixed(1) + " / " + monitorRoot.ramTotal.toFixed(1) + " GB"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: "#ffffff" }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 4; color: "#26ffffff"; radius: 0; clip: true
                        Rectangle {
                            width: parent.width * (monitorRoot.ramPercent / 100.0)
                            height: parent.height; color: "#ffffff"; radius: 0
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "DISK"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Medium; color: "#ffffff" }
                        Item { Layout.fillWidth: true }
                        Text { text: monitorRoot.diskUsed + " / " + monitorRoot.diskTotal + " GB"; font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: "#ffffff" }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 4; color: "#26ffffff"; radius: 0; clip: true
                        Rectangle {
                            width: parent.width * (monitorRoot.diskPercent / 100.0)
                            height: parent.height; color: "#ffffff"; radius: 0
                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }

            Rectangle {
                id: listDivider
                width: parent.width - 24; height: 1; color: "#26ffffff"
                x: 12; y: 154 
            }

            Text {
                id: tasksHeaderLabel
                text: "Processes"
                font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold
                color: "#ffffff"
                x: 14; y: 166 
            }

            Item {
                id: listBoundsFrame
                width: parent.width - 24
                x: 12
                anchors.top: tasksHeaderLabel.bottom
                anchors.bottom: parent.bottom
                anchors.topMargin: 6
                anchors.bottomMargin: 12

                ListView {
                    id: processListView
                    anchors.fill: parent
                    model: processListModel
                    spacing: 4
                    clip: true
                    // Constrains tracking bounds tightly to completely skip bounce physics loops
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: processListView.width
                        height: 24
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4; anchors.rightMargin: 4

                            Text {
                                text: model.name
                                font.family: "Rubik"; font.pixelSize: 11
                                color: "#59ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: model.cpu + "%"
                                font.family: "Rubik"; font.pixelSize: 11; font.weight: Font.Medium
                                color: "#ffffff"
                            }
                        }
                    }
                }
            }
        }
    }
}
