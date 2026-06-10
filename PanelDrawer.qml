import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow {
    id: drawerWindow
    
    property bool isOpen: false
    property int drawerHeight: 180
    property int drawerWidth: Config.drawerTargetWidth
    property string modalToken: ""
    property bool anchorTop: false
    
    default property alias contentCanvas: textContentGroup.data

    visible: isOpen
    color: "transparent"
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-overlay"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    onIsOpenChanged: {
        if (isOpen) {
            rootScope.requestOpen(modalToken);
            popupCard.forceActiveFocus();
        } else if (rootScope.activeModal === modalToken) {
            rootScope.dismissAll();
        }
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== modalToken && isOpen) {
                isOpen = false;
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: isOpen
        onActivated: isOpen = false
    }

    MouseArea { 
        anchors.fill: parent
        onClicked: isOpen = false 
    }

    Rectangle {
        id: popupCard
        height: drawerHeight
        x: 0
        
        anchors.top: anchorTop ? parent.top : undefined
        anchors.topMargin: anchorTop ? 12 : 0
        anchors.bottom: anchorTop ? undefined : parent.bottom
        anchors.bottomMargin: anchorTop ? 0 : 12
        
        radius: 0
        color: "#9911111b"
        border.width: 0
        clip: true
        focus: true

        states: [
            State {
                name: "visible"; when: drawerWindow.isOpen
                PropertyChanges { target: popupCard; width: drawerWindow.drawerWidth; opacity: 1.0 }
            },
            State {
                name: "hidden"; when: !drawerWindow.isOpen
                PropertyChanges { target: popupCard; width: 0; opacity: 0.0 }
            }
        ]

        transitions: [
            Transition {
                from: "hidden"; to: "visible"
                ParallelAnimation {
                    NumberAnimation { property: "width"; duration: Config.entryDuration; easing.type: Config.entryEasing }
                    NumberAnimation { property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
                }
            },
            Transition {
                from: "visible"; to: "hidden"
                SequentialAnimation {
                    ParallelAnimation {
                        NumberAnimation { property: "width"; duration: Config.exitDuration; easing.type: Config.exitEasing }
                        NumberAnimation { property: "opacity"; duration: Config.exitDuration; easing.type: Easing.InQuad }
                    }
                    ScriptAction { script: { drawerWindow.isOpen = false; } }
                }
            }
        ]

        Item {
            id: textContentGroup
            anchors.fill: parent
            opacity: popupCard.width > (drawerWindow.drawerWidth - 50) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }
    }
}