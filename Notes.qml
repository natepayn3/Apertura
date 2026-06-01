import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

Item {
    id: notesRoot
    implicitWidth: 32
    implicitHeight: 32

    property bool menuOpen: false
    property var notesList: [""]
    property int activeIndex: 0
    property bool isAlwaysVisible: false

    Timer {
        id: closeTimer
        interval: 180
        repeat: false
        onTriggered: {
            notesRoot.menuOpen = false;
        }
    }

    function toggleMenu(): void {
        if (isAlwaysVisible) {
            isAlwaysVisible = false;
            openMenu();
        } else if (menuOpen) {
            closeMenu();
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;
        
        rootScope.requestOpen("notes");
        menuOpen = true;
        
        slideInAnimation.start();
    }

    function closeMenu(): void {
        popupMenuFrame.targetX = -655;
        popupMenuFrame.targetOpacity = 0.0;
        closeTimer.start();
    }

    Connections {
        target: rootScope
        function onActiveModalChanged() {
            if (rootScope.activeModal !== "notes" && menuOpen && !isAlwaysVisible) {
                closeMenu();
            }
        }
    }

    Rectangle {
        id: notesHitbox
        anchors.fill: parent
        color: notesMouseArea.containsMouse ? "#26ffffff" : "transparent"
        radius: 0 

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "description"
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: "#ffffff"
            }
        }

        MouseArea {
            id: notesMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: notesOverlayModal
        visible: notesRoot.menuOpen || notesRoot.isAlwaysVisible
        color: "transparent"
        
        anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: notesRoot.isAlwaysVisible ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand

        mask: notesRoot.isAlwaysVisible ? notesInputBounds : null

        Region {
            id: notesInputBounds
            item: popupMenuFrame
        }

        onVisibleChanged: {
            if (visible && notesRoot.menuOpen) {
                popupMenuFrame.forceActiveFocus();
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !notesRoot.isAlwaysVisible
            onClicked: closeMenu()
        }

        Rectangle {
            id: popupMenuFrame
            width: 400
            height: 300
            
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.bottomMargin: 12
            
            property int targetX: -655
            property real targetOpacity: 0.0
            
            anchors.leftMargin: notesRoot.isAlwaysVisible ? 0 : targetX
            opacity: notesRoot.isAlwaysVisible ? 1.0 : targetOpacity

            SequentialAnimation {
                id: slideInAnimation
                PauseAnimation { duration: 16 }
                ParallelAnimation {
                    NumberAnimation { target: popupMenuFrame; property: "targetX"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                    NumberAnimation { target: popupMenuFrame; property: "targetOpacity"; to: 1.0; duration: 140; easing.type: Easing.OutQuad }
                }
            }

            Behavior on anchors.leftMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

            color: "#9911111b"
            border.width: 0
            radius: 0
            focus: true

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape && !notesRoot.isAlwaysVisible) {
                    closeMenu();
                    event.accepted = true;
                }
            }

            Component.onCompleted: popupMenuFrame.forceActiveFocus()

            MouseArea {
                id: mainContentArea
                anchors.fill: parent
                hoverEnabled: true
                onPressed: (mouse) => { mouse.accepted = true; }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text { 
                            text: "Notes"
                            font.family: "Rubik"
                            font.pixelSize: 16; font.weight: Font.Bold
                            color: "#ffffff" 
                        }
                        
                        Item { Layout.fillWidth: true }

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                id: toggleButton
                                width: 96
                                height: 24
                                radius: 0
                                visible: mainContentArea.containsMouse || btnMouseArea.containsMouse
                                color: notesRoot.isAlwaysVisible ? "#45ffffff" : "transparent"
                                border.width: notesRoot.isAlwaysVisible ? 0 : 1
                                border.color: "#26ffffff"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Always Visible"
                                    font.family: "Rubik"
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    id: btnMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    preventStealing: true
                                    onClicked: {
                                        if (notesRoot.isAlwaysVisible) {
                                            notesRoot.menuOpen = true;
                                            notesRoot.isAlwaysVisible = false;
                                        } else {
                                            notesRoot.isAlwaysVisible = true;
                                            notesRoot.menuOpen = false;
                                            if (rootScope.activeModal === "notes") {
                                                rootScope.dismissAll();
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: 24
                                height: 24
                                color: addMouse.containsMouse ? "#26ffffff" : "transparent"
                                border.width: 1
                                border.color: "#26ffffff"
                                radius: 0

                                Text {
                                    anchors.centerIn: parent
                                    text: "add"
                                    font.family: "Material Symbols Outlined"
                                    font.pixelSize: 16
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    id: addMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var list = notesRoot.notesList;
                                        list.push("");
                                        
                                        notesRoot.notesList = list.slice();
                                        notesRoot.activeIndex = notesRoot.notesList.length - 1;
                                        notesRepeater.model = notesRoot.notesList;
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#26ffffff" }

                    ScrollView {
                        Layout.fillWidth: true
                        id: tabScrollView
                        height: tabScrollView.contentWidth > tabScrollView.availableWidth ? 44 : 34
                        bottomPadding: tabScrollView.contentWidth > tabScrollView.availableWidth ? 18 : 8
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        
                        ScrollBar.horizontal: ScrollBar {
                            id: hBar
                            policy: ScrollBar.AsNeeded
                            visible: tabScrollView.contentWidth > tabScrollView.availableWidth
                            parent: tabScrollView
                            x: tabScrollView.leftPadding
                            y: tabScrollView.height - height
                            width: tabScrollView.availableWidth
                            
                            contentItem: Rectangle {
                                implicitHeight: 5
                                color: hBar.hovered || hBar.pressed ? "#45ffffff" : "#26ffffff"
                                radius: 0
                            }

                            background: Rectangle {
                                implicitHeight: 5
                                color: "transparent"
                            }
                        }

                        Row {
                            id: tabRow
                            spacing: 6
                            width: implicitWidth

                            Repeater {
                                id: notesRepeater
                                model: notesRoot.notesList
                                delegate: Rectangle {
                                    width: tabText.implicitWidth + 36
                                    height: 26
                                    color: notesRoot.activeIndex === index ? "#45ffffff" : (tabMouse.containsMouse ? "#26ffffff" : "transparent")
                                    border.width: notesRoot.activeIndex === index ? 0 : 1
                                    border.color: "#26ffffff"
                                    radius: 0

                                    Text {
                                        id: tabText
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Note " + (index + 1)
                                        font.family: "Rubik"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                        color: "#ffffff"
                                    }

                                    Text {
                                        id: closeIcon
                                        anchors.right: parent.right
                                        anchors.rightMargin: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "close"
                                        font.family: "Material Symbols Outlined"
                                        font.pixelSize: 12
                                        color: closeTabMouse.containsMouse ? "#ffffff" : "#59ffffff"
                                        z: 5

                                        MouseArea {
                                            id: closeTabMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var list = notesRoot.notesList;
                                                if (list.length > 1) {
                                                    list.splice(index, 1);
                                                    
                                                    let nextIndex = notesRoot.activeIndex;
                                                    if (nextIndex >= list.length) {
                                                        nextIndex = list.length - 1;
                                                    }
                                                    
                                                    notesRoot.notesList = list.slice();
                                                    notesRoot.activeIndex = nextIndex;
                                                    notesRepeater.model = notesRoot.notesList;
                                                } else if (list.length === 1) {
                                                    // Clear text fields cleanly if only one note tab is left open
                                                    list[0] = "";
                                                    notesRoot.notesList = list.slice();
                                                    notesRoot.activeIndex = 0;
                                                    notesRepeater.model = notesRoot.notesList;
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: tabMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            notesRoot.activeIndex = index;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#5911111b"
                        border.color: "#26ffffff"
                        border.width: 1
                        radius: 0

                        ScrollView {
                            id: noteScroll
                            anchors.fill: parent
                            clip: true

                            TextArea {
                                id: noteTextArea
                                width: noteScroll.width
                                height: noteScroll.height
                                font.family: "Rubik"
                                font.pixelSize: 13
                                color: "#ffffff"
                                wrapMode: TextEdit.WordWrap
                                selectByMouse: true
                                background: null
                                padding: 8
                                
                                text: notesRoot.notesList[notesRoot.activeIndex] || ""

                                onTextEdited: {
                                    var list = notesRoot.notesList;
                                    list[notesRoot.activeIndex] = text;
                                    notesRoot.notesList = list.slice();
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
