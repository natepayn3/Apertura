import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "."

Item {
    id: notificationRoot
    implicitWidth: 32
    implicitHeight: 32

    property int unreadCount: 0
    property var visibleBanners: []
    property var activeHistoryReferences: [] 
    property bool menuOpen: false
    property bool notificationsEnabled: true

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
        if (notificationMouseArea.containsMouse || cardHoverTracker.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (drawerTemplate.isOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    function updateCount() {
        if (!notificationRoot.notificationsEnabled) {
            notificationRoot.unreadCount = 0;
            return;
        }
        if (nativeServer && nativeServer.trackedNotifications) {
            notificationRoot.unreadCount = nativeServer.trackedNotifications.rowCount();
        }
    }

    NotificationServer {
        id: nativeServer
        bodySupported: true
        actionsSupported: true
        keepOnReload: true

        onNotification: (notification) => {
            if (!notificationRoot.notificationsEnabled) {
                notification.dismiss();
                return;
            }
            
            notification.tracked = true;
            notificationRoot.updateCount();
            notificationRoot.activeHistoryReferences = [...notificationRoot.activeHistoryReferences, notification];
            notificationRoot.visibleBanners = [...notificationRoot.visibleBanners, notification];

            let toastTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 5000; running: true; repeat: false }', notificationRoot);
            toastTimer.triggered.connect(() => {
                notificationRoot.visibleBanners = notificationRoot.visibleBanners.filter(item => item !== notification);
                toastTimer.destroy();
            });
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: notificationRoot.updateCount()
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== drawerTemplate.modalToken && drawerTemplate.isOpen) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: notificationHitbox
        anchors.fill: parent
        color: notificationMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
        radius: 0 

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                id: notificationIcon
                Layout.alignment: Qt.AlignHCenter
                text: !notificationRoot.notificationsEnabled ? "notifications_off" : (notificationRoot.unreadCount > 0 ? "notifications_unread" : "notifications")
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: notificationRoot.notificationsEnabled ? (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
            }
        }

        MouseArea {
            id: notificationMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
            onContainsMouseChanged: checkUserActivity()
            
            onDoubleClicked: {
                if (!notificationRoot.notificationsEnabled) return;
                try { nativeServer.clear(); } catch(e) {}
                try { nativeServer.dismissAll(); } catch(e) {}
                for (let i = 0; i < notificationRoot.activeHistoryReferences.length; i++) {
                    try { notificationRoot.activeHistoryReferences[i].dismiss(); } catch(e) {}
                    try { nativeServer.dismiss(notificationRoot.activeHistoryReferences[i].id); } catch(e) {}
                }
                notificationRoot.visibleBanners = [];
                notificationRoot.activeHistoryReferences = [];
            }
        }
    }

    PanelWindow {
        id: popupToastWindow
        visible: notificationRoot.visibleBanners.length > 0 && !drawerTemplate.isOpen && notificationRoot.notificationsEnabled
        color: "transparent"
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Fixed: Map the input bounding layout box down to Wayland context so clicks fall through empty space
        mask: toastInputBounds

        Region {
            id: toastInputBounds
            item: toastColumn
        }

        ColumnLayout {
            id: toastColumn
            width: Config.drawerTargetWidth 
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            spacing: 8

            states: [
                State {
                    name: "visible"
                    when: notificationRoot.visibleBanners.length > 0
                    PropertyChanges { target: toastColumn; x: 0 }
                },
                State {
                    name: "hidden"
                    when: notificationRoot.visibleBanners.length === 0
                    PropertyChanges { target: toastColumn; x: -320 }
                }
            ]

            transitions: [
                Transition {
                    from: "hidden"; to: "visible"
                    ParallelAnimation {
                        NumberAnimation { property: "x"; duration: Config.entryDuration; easing.type: Config.entryEasing }
                    }
                },
                Transition {
                    from: "visible"; to: "hidden"
                    ParallelAnimation {
                        NumberAnimation { property: "x"; duration: Config.exitDuration; easing.type: Config.exitEasing }
                    }
                }
            ]

            Repeater {
                model: notificationRoot.visibleBanners
                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(60, tSummary.implicitHeight + tBody.implicitHeight + 20)
                    color: "#9911111b" 
                    border.width: 0
                    radius: 0

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            id: tSummary
                            text: modelData.summary
                            font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }

                        Text {
                            id: tBody
                            text: modelData.body
                            font.family: "Rubik"; font.pixelSize: 12; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                            Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 4; elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            notificationRoot.visibleBanners = notificationRoot.visibleBanners.filter(item => item !== modelData);
                        }
                    }
                }
            }
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        modalToken: "notifications"
        anchorTop: false

        drawerHeight: !notificationRoot.notificationsEnabled ? 92 : (notifListView.count === 0 ? 96 : Math.min(56 + (notifListView.count * 62), 300))

        onIsOpenChanged: {
            if (isOpen) {
                notificationRoot.menuOpen = true;
                checkUserActivity();
                mainContainerLayout.forceActiveFocus();
            } else {
                notificationRoot.menuOpen = false;
            }
        }

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

        ColumnLayout {
            id: mainContainerLayout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            focus: true

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Notifications"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" } 
                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 12
                    Layout.alignment: Qt.AlignRight

                    Item {
                        width: clearAllText.implicitWidth
                        height: 24
                        visible: notificationRoot.unreadCount > 0 && notificationRoot.notificationsEnabled
                        z: 100

                        Text {
                            id: clearAllText
                            anchors.centerIn: parent
                            text: "Clear All"
                            font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold
                            color: clearAllMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
                        }

                        MouseArea {
                            id: clearAllMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                try { nativeServer.clear(); } catch(e) {}
                                try { nativeServer.dismissAll(); } catch(e) {}
                                
                                for (let i = 0; i < notificationRoot.activeHistoryReferences.length; i++) {
                                    let item = notificationRoot.activeHistoryReferences[i];
                                    if (item) {
                                        try { item.dismiss(); } catch(e) {}
                                        try { nativeServer.dismiss(item.id); } catch(e) {}
                                    }
                                }
                                
                                notificationRoot.visibleBanners = [];
                                notificationRoot.activeHistoryReferences = [];
                                notificationRoot.updateCount();
                                checkUserActivity();
                            }
                        }
                    }

                    Rectangle {
                        width: 50; height: 24; radius: 12
                        color: notificationRoot.notificationsEnabled ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                        z: 100
                        
                        Rectangle {
                            width: 18; height: 18; radius: 9; color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
                            anchors.verticalCenter: parent.verticalCenter
                            x: notificationRoot.notificationsEnabled ? 28 : 4
                            Behavior on x { NumberAnimation { duration: 120 } }
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                notificationRoot.notificationsEnabled = !notificationRoot.notificationsEnabled;
                                if (!notificationRoot.notificationsEnabled) {
                                    try { nativeServer.clear(); } catch(e) {}
                                    try { nativeServer.dismissAll(); } catch(e) {}
                                    
                                    for (let i = 0; i < notificationRoot.activeHistoryReferences.length; i++) {
                                        let item = notificationRoot.activeHistoryReferences[i];
                                        if (item) {
                                            try { item.dismiss(); } catch(e) {}
                                            try { nativeServer.dismiss(item.id); } catch(e) {}
                                        }
                                    }
                                    
                                    notificationRoot.visibleBanners = [];
                                    notificationRoot.activeHistoryReferences = [];
                                }
                                notificationRoot.updateCount();
                                checkUserActivity();
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff" }

            Item {
                id: listContainer
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: notificationRoot.notificationsEnabled

                ListView {
                    id: notifListView
                    anchors.fill: parent
                    clip: true; spacing: 8
                    model: nativeServer.trackedNotifications

                    Text {
                        anchors.centerIn: parent
                        text: "No new notifications"
                        font.family: "Rubik"; font.pixelSize: 13; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff" 
                        visible: notifListView.count === 0 && notificationRoot.notificationsEnabled
                    }

                    delegate: Item {
                        width: notifListView.width
                        height: Math.max(50, summaryLabel.implicitHeight + bodyLabel.implicitHeight + 16)

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.color: cellMouseArea.containsMouse ? (rootScope.theme ? rootScope.theme.theme_primary : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") 
                            border.width: 1
                            radius: 0 

                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 10; spacing: 2

                                Text {
                                    id: summaryLabel
                                    text: modelData.summary
                                    font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold
                                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                                    Layout.fillWidth: true; elide: Text.ElideRight
                                }

                                Text {
                                    id: bodyLabel
                                    text: modelData.body
                                    font.family: "Rubik"; font.pixelSize: 12; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                                    Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                                }
                            }
                            
                            MouseArea {
                                id: cellMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    try { nativeServer.dismiss(modelData.id); } catch(e) {}
                                    try { modelData.dismiss(); } catch(e) {}
                                    notificationRoot.updateCount();
                                    checkUserActivity();
                                }
                            }
                        }
                    }
                }
            }

            Text {
                id: mutedPlaceholder
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: "Notifications are muted"
                font.family: "Rubik"; font.pixelSize: 13; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                visible: !notificationRoot.notificationsEnabled
            }
        }
    }
}
