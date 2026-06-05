import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQml.Models
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "."

Scope {
    id: rootScope

    property var configurationAsset: Config

    property alias theme: theme 

    Theme { id: theme }

    property var activeModal: null
    property bool audioSliderActive: false
    property var instantiatedBars: ({})
    property bool sessionLocked: false

    function requestOpen(modalName) { activeModal = modalName; }
    function dismissAll() { activeModal = null; }

    function checkIsVertical(wsId) {
        let targetWsObj = Hyprland.workspaces.values.find(ws => ws.id === wsId);
        let monitorObj = targetWsObj ? targetWsObj.monitor : (Hyprland.activeMonitor || null);
        
        if (monitorObj) {
            return monitorObj.height > monitorObj.width;
        }
        return wsId >= 10;
    }

    PanelWindow {
        id: globalWorkspacePreview
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-workspace-preview"
        WlrLayershell.keyboardFocus: WlrLayershell.None

        anchors { left: true; top: true }

        property int targetWorkspace: -1
        property int marginLeft: 0
        property int marginTop: 0

        function requestDismiss() {
            dismissTimer.restart();
        }

        function cancelDismiss() {
            dismissTimer.stop();
        }

        Timer {
            id: dismissTimer
            interval: 1000
            running: false
            repeat: false
            onTriggered: globalWorkspacePreview.targetWorkspace = -1
        }

        onMarginLeftChanged: globalWorkspacePreview.WlrLayershell.margins.left = marginLeft
        onMarginTopChanged: globalWorkspacePreview.WlrLayershell.margins.top = marginTop

        visible: targetWorkspace !== -1 || popupCard.state === "visible"

        implicitWidth: 1050
        implicitHeight: 700
        color: "transparent"

        Item {
            id: globalLayoutWrapper
            width: 1000
            height: 700

            MouseArea {
                id: masterContainerTracker
                anchors.fill: parent
                hoverEnabled: true
                onEntered: globalWorkspacePreview.cancelDismiss()
                onExited: globalWorkspacePreview.requestDismiss()

                Rectangle {
                    id: popupCard
                    height: previewEngine.height
                    anchors.left: parent.left
                    
                    color: "#9911111b"
                    border.width: 0
                    radius: 0
                    clip: true

                    Behavior on height {
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
                    }

                    states: [
                        State {
                            name: "visible"; when: previewEngine.active
                            PropertyChanges { 
                                target: popupCard; 
                                width: previewEngine.renderReady ? Math.min(1000, layoutFocusWrapper.width) : Math.min(1000, layoutFocusWrapper.width)
                                height: previewEngine.height
                                opacity: 1.0 
                            }
                        },
                        State {
                            name: "hidden"; when: !previewEngine.active
                            PropertyChanges { 
                                target: popupCard; 
                                width: 0; 
                                height: previewEngine.height; 
                                opacity: 0.0 
                            }
                        }
                    ]

                    transitions: [
                        Transition {
                            from: "hidden"; to: "visible"
                            ParallelAnimation {
                                NumberAnimation { 
                                    target: popupCard; 
                                    property: "width"; 
                                    duration: Config.entryDuration; 
                                    easing.type: Config.entryEasing 
                                }
                                NumberAnimation { target: popupCard; property: "height"; duration: 200; easing.type: Easing.OutCubic }
                                NumberAnimation { target: popupCard; property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                            }
                        },
                        Transition {
                            from: "visible"; to: "hidden"
                            ParallelAnimation {
                                NumberAnimation { target: popupCard; property: "width"; duration: Config.exitDuration; easing.type: Config.exitEasing }
                                NumberAnimation { target: popupCard; property: "height"; duration: Config.exitDuration; easing.type: Config.exitEasing }
                                NumberAnimation { target: popupCard; property: "opacity"; duration: Config.exitDuration; easing.type: Config.exitEasing }
                            }
                        }
                    ]

                    Flickable {
                        id: scrollViewport
                        anchors.fill: parent
                        
                        contentWidth: layoutFocusWrapper.width + 16
                        contentHeight: layoutFocusWrapper.height
                        
                        flickableDirection: Flickable.HorizontalFlick
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        Item {
                            id: layoutFocusWrapper
                            width: previewEngine.neededWidth
                            height: previewEngine.height

                            WorkspacePreview {
                                id: previewEngine
                                targetWorkspace: globalWorkspacePreview.targetWorkspace
                                theme: rootScope.theme
                                opacity: popupCard.width > 200 ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            }
                        }

                        // Fixed: Global transparent tracker overlay sits cleanly on top of the scrolling canvas tracking block
                        // to handle exit events seamlessly across window controls and background assets alike
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            z: 100 // Places tracker stack layer over child rendering targets
                            acceptedButtons: Qt.NoButton // Passes clicks straight through down to underlying buttons/elements
                            
                            onEntered: globalWorkspacePreview.cancelDismiss()
                            onExited: globalWorkspacePreview.requestDismiss()
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].appLauncherModule)
                    rootScope.instantiatedBars[s].appLauncherModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].wallpaperModule)
                    rootScope.instantiatedBars[s].wallpaperModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "notes"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].notesModule)
                    rootScope.instantiatedBars[s].notesModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "sysmonitor"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].sysMonitorModule)
                    rootScope.instantiatedBars[s].sysMonitorModule.toggleMenu();
        }
    }

    IpcHandler {
        target: "netmonitor"
        function toggle(): void {
            for (let s in rootScope.instantiatedBars)
                if (rootScope.instantiatedBars[s].netMonitorModule)
                    rootScope.instantiatedBars[s].netMonitorModule.toggleMenu();
        }
    }

    Instantiator {
        id: barWindows
        model: Quickshell.screens

        delegate: Scope {
            VolumeHud { targetScreen: modelData }

            DesktopClock {
                screen: modelData
            }

            PanelWindow {
                id: mainBarWindow
                property string screenKey: modelData.name

                Component.onCompleted: { rootScope.instantiatedBars[screenKey] = mainBarWindow; }
                Component.onDestruction: { delete rootScope.instantiatedBars[screenKey]; }

                property alias appLauncherModule: appLauncherItem
                property alias wallpaperModule: wallpaperItem
                property alias calendarModule: calendarItem
                property alias notesModule: notesItem
                property alias sysMonitorModule: sysMonitorItem
                property alias netMonitorModule: netMonitorItem
                
                readonly property var previewPopup: globalWorkspacePreview

                screen: modelData
                anchors { left: true; top: true; bottom: true }
                implicitWidth: 54
                color: "transparent"

                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "quickshell-bar"
                WlrLayershell.margins.top: 12; WlrLayershell.margins.bottom: 12; WlrLayershell.margins.left: 12; WlrLayershell.margins.right: 0

                Rectangle {
                    anchors.fill: parent
                    color: "#9911111b"

                    MouseArea { 
                        anchors.fill: parent
                        hoverEnabled: true
                        z: -1
                        onPressed: rootScope.dismissAll() 
                    }

                    Column {
                        id: topStackColumn
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.topMargin: 16
                        spacing: 12

                        AppLauncher { id: appLauncherItem; anchors.horizontalCenter: parent.horizontalCenter }
                        Wallpaper { id: wallpaperItem; anchors.horizontalCenter: parent.horizontalCenter; property int barHeight: mainBarWindow.height }
                        Calendar { id: calendarItem; anchors.horizontalCenter: parent.horizontalCenter }
                        
                        Item {
                            width: 32
                            height: 56
                            anchors.horizontalCenter: parent.horizontalCenter

                            Cava {
                                anchors.centerIn: parent
                                themeContext: rootScope.theme
                            }
                        }

                        Workspaces { 
                            theme: rootScope.theme 
                            anchors.horizontalCenter: parent.horizontalCenter; z: 1 
                        }
                    }

                    ColumnLayout {
                        id: bottomGroupControls
                        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottomMargin: 16
                        spacing: 8 
                        property bool isExpanded: false

                        Rectangle {
                            id: toggleButton
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignHCenter
                            color: "transparent"
                            radius: 0

                            Text {
                                anchors.centerIn: parent
                                text: bottomGroupControls.isExpanded ? "arrow_drop_down" : "arrow_drop_up"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 30
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            }

                            Rectangle {
                                id: toggleHoverOverlay
                                anchors.fill: parent
                                radius: 0
                                color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                opacity: toggleMouseArea.containsMouse ? 0.3 : 0.0
                                z: 1
                            }

                            MouseArea {
                                id: toggleMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.LeftButton) {
                                        bottomGroupControls.isExpanded = !bottomGroupControls.isExpanded
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            id: modulesColumn
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            component DrawerModule : Item {
                                id: moduleWrapper
                                property bool isPinned: false
                                property bool moduleAvailable: true
                                default property alias moduleData: container.data

                                readonly property bool shouldBeActive: (bottomGroupControls.isExpanded || isPinned) && moduleAvailable

                                property int targetHeight: shouldBeActive ? 38 : 0
                                Behavior on targetHeight {
                                    NumberAnimation {
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Layout.preferredWidth: shouldBeActive ? 38 : 0
                                Layout.preferredHeight: targetHeight
                                Layout.alignment: Qt.AlignHCenter
                                
                                visible: targetHeight > 0
                                opacity: targetHeight / 38

                                width: 38
                                height: 38

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 0
                                    color: "transparent"
                                    border.width: isPinned && bottomGroupControls.isExpanded ? 1 : 0
                                    border.color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                }

                                Item {
                                    id: container
                                    width: 32
                                    height: 32
                                    anchors.centerIn: parent
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            moduleWrapper.isPinned = !moduleWrapper.isPinned
                                        }
                                    }
                                }
                            }

                            DrawerModule {
                                id: wrapWifi
                                moduleAvailable: wifiItem.hasWifiCard
                                Wifi { id: wifiItem; anchors.centerIn: parent }
                            }

                            DrawerModule {
                                id: wrapBattery
                                moduleAvailable: batteryItem.isLaptop
                                Battery { id: batteryItem; anchors.centerIn: parent }
                            }

                            DrawerModule {
                                id: wrapSnip
                                Rectangle {
                                    id: screensnipButton
                                    width: 32
                                    height: 32
                                    anchors.centerIn: parent
                                    color: "transparent"
                                    radius: 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "screenshot_region"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 22
                                        color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                    }

                                    Rectangle {
                                        id: snipHoverOverlay
                                        anchors.fill: parent
                                        radius: 0
                                        color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
                                        opacity: snipMouseArea.containsMouse ? 0.3 : 0.0
                                        z: 1
                                    }

                                    MouseArea {
                                        id: snipMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Quickshell.execDetached([
                                                "bash", "-c", 
                                                "grim -g \"$(slurp)\" -t ppm - | satty --filename -"
                                            ]);
                                        }
                                    }
                                }
                            }

                            DrawerModule { id: wrapNotes; Notes { id: notesItem; anchors.centerIn: parent } }
                            DrawerModule { id: wrapNotif; Notification { anchors.centerIn: parent } }
                            DrawerModule { id: wrapBlue; Bluetooth { anchors.centerIn: parent } }
                            DrawerModule { id: wrapAudio; Audio { anchors.centerIn: parent } }
                            DrawerModule { id: wrapSys; SysMonitor { id: sysMonitorItem; theme: rootScope.theme; anchors.centerIn: parent } }
                            DrawerModule { id: wrapNet; NetMonitor { id: netMonitorItem; anchors.centerIn: parent } }
                            DrawerModule { id: wrapPower; Power { anchors.centerIn: parent } }
                        }
                    }
                }
            }
        }
    }
}
