import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Item {
    id: notificationRoot
    implicitWidth: 32
    implicitHeight: 32

    property int unreadCount: 0
    
    // Custom storage arrays to keep references clean and mutable
    property var visibleBanners: []
    property var activeHistoryReferences: [] 

    // Controls actual history card PanelWindow visibility
    property bool menuOpen: false

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
            notificationRoot.menuOpen = false;
            rootScope.dismissAll();
        }
    }

    // 🔓 PUBLIC INTERFACE (Targeted by manual toggles)
    function toggleMenu(): void {
        if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        // Reset hidden baseline coordinates before mapping window surface
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;

        rootScope.requestOpen(notificationOverlayModal);
        menuOpen = true;

        // Drive the entry transition timeline sequentially
        slideInAnimation.start();
        checkUserActivity();
    }

    function closeMenu(): void {
        // Animate out while the window layer shell surface is still active
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;

        closeTimer.start();
    }

    // Helper logic to cleanly handle user presence changes
    function checkUserActivity() {
        if (cardHoverTracker.containsMouse || listContainerMouse.containsMouse) {
            osdAutohideTimer.stop(); // Interacting: Freeze dismissal rule
        } else if (notificationOverlayModal.visible && menuOpen) {
            osdAutohideTimer.restart(); // Left environment bounds: Start countdown ticking
        }
    }

    function updateCount() {
        if (nativeServer && nativeServer.trackedNotifications) {
            notificationRoot.unreadCount = nativeServer.trackedNotifications.rowCount();
        }
    }

    // 📡 NATIVE DESKTOP NOTIFICATION SERVER
    NotificationServer {
        id: nativeServer
        
        bodySupported: true
        actionsSupported: true
        keepOnReload: true

        onNotification: (notification) => {
            notification.tracked = true;
            notificationRoot.updateCount();

            // Store raw mutable references for fallback tracking
            notificationRoot.activeHistoryReferences = [...notificationRoot.activeHistoryReferences, notification];
            notificationRoot.visibleBanners = [...notificationRoot.visibleBanners, notification];

            // Trigger a separate horizontal slide entry sequence specifically for the new toast alert element
            toastSlideIn.restart();

            // Auto-evict the banner slot from the floating HUD after 5 seconds
            let toastTimer = Qt.createQmlObject('import QtQuick; Timer { interval: 5000; running: true; repeat: false }', notificationRoot);
            toastTimer.triggered.connect(() => {
                notificationRoot.visibleBanners = notificationRoot.visibleBanners.filter(item => item !== notification);
                toastTimer.destroy();
            });
        }
    }

    // Steady state scan loop to verify cache allocations
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: notificationRoot.updateCount()
    }

    // 🎨 UI PANEL TRIGGER BUTTON
    Rectangle {
        id: notificationHitbox
        anchors.fill: parent
        color: notificationMouseArea.containsMouse ? "#313244" : "transparent"
        radius: 8

        Text {
            anchors.centerIn: parent
            text: notificationRoot.unreadCount > 0 ? "󱅫" : "󰂚"
            font.family: "Rubik"
            font.pixelSize: 20
            color: notificationRoot.unreadCount > 0 ? "#f38ba8" : "#cdd6f4"
        }

        // Alert Pill Counter Badge Accent
        Rectangle {
            width: 14; height: 14; radius: 7; color: "#f38ba8"
            visible: notificationRoot.unreadCount > 0
            anchors.top: parent.top; anchors.right: parent.right
            anchors.topMargin: 2; anchors.rightMargin: 2

            Text {
                anchors.centerIn: parent
                text: notificationRoot.unreadCount.toString()
                font.family: "Rubik"; font.pixelSize: 9; font.weight: Font.Bold; color: "#11111b"
            }
        }

        MouseArea {
            id: notificationMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
            
            onDoubleClicked: {
                try { nativeServer.clear(); } catch(e) {}
                try { nativeServer.dismissAll(); } catch(e) {}
                for (let i = 0; i < notificationRoot.activeHistoryReferences.length; i++) {
                    try { notificationRoot.activeHistoryReferences[i].dismiss(); } catch(e) {}
                    try { nativeServer.dismiss(notificationRoot.activeHistoryReferences[i].id); } catch(e) {}
                }
                notificationRoot.visibleBanners = [];
                notificationRoot.activeHistoryReferences = [];
                notificationRoot.updateCount();
            }
        }
    }

    // 🔄 GLOBAL CLEANUP LISTENER
    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== notificationOverlayModal && menuOpen) {
                closeMenu();
            }
        }
    }

    // ==========================================
    // 🪟 1. FLOATING DESKTOP BANNER POPUPS (Bubbly HUD)
    // ==========================================
    PanelWindow {
        id: popupToastWindow
        visible: notificationRoot.visibleBanners.length > 0 && !notificationOverlayModal.visible
        color: "transparent"
        
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        
        // Pass-through notification layers completely ignore keyboard interaction states
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        ColumnLayout {
            id: toastColumn
            width: 300 
            
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 12
            
            property int targetX: 5
            anchors.leftMargin: targetX
            spacing: 8

            // Floating alert banners slide in natively on creation pass
            NumberAnimation { id: toastSlideIn; target: toastColumn; property: "targetX"; from: -320; to: 5; duration: 180; easing.type: Easing.OutCubic }

            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Repeater {
                model: notificationRoot.visibleBanners

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(60, tSummary.implicitHeight + tBody.implicitHeight + 20)
                    color: "#cc11111b" 
                    border.color: "#898989"
                    border.width: 1
                    radius: 12

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            id: tSummary
                            text: modelData.summary
                            font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#cdd6f4"
                            Layout.fillWidth: true; elide: Text.ElideRight
                        }

                        Text {
                            id: tBody
                            text: modelData.body
                            font.family: "Rubik"; font.pixelSize: 12; color: "#a6adc8"
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

    // ==========================================
    // 🪟 2. NATIVE HISTORY OVERLAY MENU CARD
    // ==========================================
    PanelWindow {
        id: notificationOverlayModal
        visible: notificationRoot.menuOpen
        color: "transparent"
        
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible && notificationRoot.menuOpen) {
                popupMenuFrame.forceActiveFocus();
            }
        }

        MouseArea { anchors.fill: parent; onClicked: closeMenu() }

        Rectangle {
            id: popupMenuFrame
            width: 300 
            
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 12
            
            // Mutable animation target maps
            property int targetX: -655
            property real targetOpacity: 0.0

            anchors.leftMargin: targetX
            opacity: targetOpacity

            // ✨ ENTRY SEQUENCE: Solves the birth frame asset mapping bug
            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupMenuFrame; property: "targetX"; to: 5; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupMenuFrame; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            // ✨ EXIT SLIDE IMPLICIT TRACKER
            Behavior on anchors.leftMargin {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            
            // ✨ EXIT FADE IMPLICIT TRACKER
            Behavior on opacity {
                NumberAnimation { duration: 140; easing.type: Easing.OutQuad }
            }

            color: "#cc11111b"; border.color: "#898989"; border.width: 1; radius: 12 
            
            height: notifListView.count === 0 ? 96 : Math.min(56 + (notifListView.count * 62), 300)
            
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    closeMenu();
                    event.accepted = true;
                }
            }
            
            Component.onCompleted: popupMenuFrame.forceActiveFocus()
            
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
                anchors.fill: parent; anchors.margins: 14; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Notifications"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#cdd6f4" } 
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: "Clear All"
                        font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold
                        color: clearAllMouse.containsMouse ? "#f38ba8" : "#585b70"
                        visible: notificationRoot.unreadCount > 0
                        
                        MouseArea {
                            id: clearAllMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
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
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

                Item {
                    id: listContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    MouseArea {
                        id: listContainerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                        onContainsMouseChanged: checkUserActivity()
                    }

                    ListView {
                        id: notifListView
                        anchors.fill: parent
                        clip: true; spacing: 8
                        model: nativeServer.trackedNotifications

                        Text {
                            anchors.centerIn: parent
                            text: "No new notifications"
                            font.family: "Rubik"; font.pixelSize: 13; color: "#a6adc8" 
                            visible: notifListView.count === 0
                        }

                        delegate: Item {
                            width: notifListView.width
                            height: Math.max(50, summaryLabel.implicitHeight + bodyLabel.implicitHeight + 16)

                            Rectangle {
                                anchors.fill: parent
                                color: "#11111b"
                                border.color: cellMouseArea.containsMouse ? "#898989" : "#313244" 
                                border.width: 1
                                radius: 8

                                ColumnLayout {
                                    anchors.fill: parent; anchors.margins: 10; spacing: 2

                                    Text {
                                        id: summaryLabel
                                        text: modelData.summary
                                        font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold
                                        color: "#cdd6f4" 
                                        Layout.fillWidth: true; elide: Text.ElideRight
                                    }

                                    Text {
                                        id: bodyLabel
                                        text: modelData.body
                                        font.family: "Rubik"; font.pixelSize: 12; color: "#a6adc8"
                                        Layout.fillWidth: true; wrapMode: Text.WordWrap; 
                                        maximumLineCount: 3
                                        elide: Text.ElideRight
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
            }
        }
    }
}
