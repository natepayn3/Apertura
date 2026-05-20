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
    property var activeHistoryReferences: [] // 🎯 THE FIX: Keeps raw mutable references safe from read-only lists

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
            
            onClicked: {
                notificationOverlayModal.visible = !notificationOverlayModal.visible;
            }
            
            onDoubleClicked: {
                // Multi-version fallback block for double click shortcut
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

    // ==========================================
    // 🪟 1. FLOATING DESKTOP BANNER POPUPS (Bubbly HUD)
    // ==========================================
    PanelWindow {
        id: popupToastWindow
        visible: notificationRoot.visibleBanners.length > 0 && !notificationOverlayModal.visible
        color: "transparent"
        
        anchors.top: true
        anchors.right: true
        
        implicitWidth: 340
        implicitHeight: toastColumn.implicitHeight + 40
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-notifications"

        ColumnLayout {
            id: toastColumn
            width: 320
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12   // 🔒 PRESERVED: Stays flush with your bar baseline bounds
            anchors.rightMargin: 20
            spacing: 8

            Repeater {
                model: notificationRoot.visibleBanners

                delegate: Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(60, tSummary.implicitHeight + tBody.implicitHeight + 20)
                    color: "#EE1e1e2e"
                    border.color: "#313244"
                    border.width: 1
                    radius: 8

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
        visible: false
        color: "transparent"
        
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        onVisibleChanged: {
            if (visible) {
                popupMenuFrame.forceActiveFocus();
            }
        }

        MouseArea { anchors.fill: parent; onClicked: notificationOverlayModal.visible = false }

        Rectangle {
            id: popupMenuFrame
            width: 340
            height: 350
            
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 12   // 🔒 PRESERVED: Stays flush with your bar baseline bounds
            anchors.rightMargin: 80 

            color: "#EE1e1e2e"; border.color: "#313244"; border.width: 1; radius: 12
            
            focus: true
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    notificationOverlayModal.visible = false;
                    event.accepted = true;
                }
            }
            
            Component.onCompleted: popupMenuFrame.forceActiveFocus()
            MouseArea { anchors.fill: parent; onPressed: (mouse) => mouse.accepted = true }

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 14; spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Notifications"; font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: "#b4befe" }
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
                                // 🎯 THE FIX: Fire a combined multi-method strategy directly at the server component
                                try { nativeServer.clear(); } catch(e) {}
                                try { nativeServer.dismissAll(); } catch(e) {}
                                
                                // 🎯 THE FIX: Loop our clean, out-of-model mutable reference stack
                                for (let i = 0; i < notificationRoot.activeHistoryReferences.length; i++) {
                                    let item = notificationRoot.activeHistoryReferences[i];
                                    if (item) {
                                        try { item.dismiss(); } catch(e) {}
                                        try { nativeServer.dismiss(item.id); } catch(e) {}
                                    }
                                }
                                
                                // Reset our custom monitoring matrices
                                notificationRoot.visibleBanners = [];
                                notificationRoot.activeHistoryReferences = [];
                                notificationRoot.updateCount();
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#313244" }

                ListView {
                    id: notifListView
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 8
                    model: nativeServer.trackedNotifications

                    Text {
                        anchors.centerIn: parent
                        text: "No new notifications"
                        font.family: "Rubik"; font.pixelSize: 13; color: "#585b70"
                        visible: nativeServer.trackedNotifications.rowCount() === 0
                    }

                    delegate: Item {
                        width: notifListView.width
                        height: Math.max(50, summaryLabel.implicitHeight + bodyLabel.implicitHeight + 16)

                        Rectangle {
                            anchors.fill: parent; color: "#11111b"; border.color: "#313244"; border.width: 1; radius: 8

                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 10; spacing: 2

                                Text {
                                    id: summaryLabel
                                    text: modelData.summary
                                    font.family: "Rubik"; font.pixelSize: 13; font.weight: Font.Bold; color: "#cdd6f4"
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
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // Individual card dismissal bypass routines
                                    try { nativeServer.dismiss(modelData.id); } catch(e) {}
                                    try { modelData.dismiss(); } catch(e) {}
                                    notificationRoot.updateCount();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}