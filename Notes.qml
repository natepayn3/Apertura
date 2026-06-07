import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "."

Item {
    id: notesRoot
    implicitWidth: 32
    implicitHeight: 32

    property bool menuOpen: false
    property var notesList: [""]
    property int activeIndex: 0
    property bool isAlwaysVisible: false
    
    property bool isDetachedInstance: false
    property bool isDetachedElsewhere: false
    
    signal closeDetachedRequested(var finalSubList, int finalSubIndex)

    function toggleMenu(): void {
        if (isDetachedElsewhere) return;
        
        if (isAlwaysVisible) {
            if (menuOpen) {
                closeMenu();
            } else {
                openMenu();
            }
        } else if (menuOpen) {
            closeMenu();
            if (rootScope.activeModal === "notes") {
                rootScope.dismissAll();
            }
        } else {
            openMenu();
        }
    }

    function openMenu(): void {
        rootScope.requestOpen("notes");
        menuOpen = true;
        if (!notesRoot.isAlwaysVisible) {
            dismissTimer.restart();
        }
    }

    function closeMenu(): void {
        menuOpen = false; 
        dismissTimer.stop();
    }

    function detachModule(): void {
        isDetachedElsewhere = true;
        closeMenu();
        if (rootScope.activeModal === "notes") {
            rootScope.dismissAll();
        }
        
        let primaryScreen = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        let initialX = 10; 
        let initialY = primaryScreen ? Math.round((primaryScreen.height - 300) / 2) : 250; 
        
        detachedWindowWrapper.createObject(rootScope, {
            "passedNotesList": notesRoot.notesList,
            "passedActiveIndex": notesRoot.activeIndex,
            "passedAlwaysVisible": notesRoot.isAlwaysVisible,
            "spawnX": initialX
        });
    }

    Timer {
        id: dismissTimer
        interval: 3500
        running: false
        repeat: false
        onTriggered: {
            if (!notesRoot.isAlwaysVisible && !notesRoot.isDetachedElsewhere) {
                notesRoot.closeMenu();
                if (rootScope.activeModal === "notes") {
                    rootScope.dismissAll();
                }
            }
        }
    }

    Connections {
        target: rootScope
        ignoreUnknownSignals: true

        function onActiveModalChanged() {
            if (rootScope.activeModal !== "notes" && notesRoot.menuOpen && !notesRoot.isAlwaysVisible) {
                notesRoot.closeMenu();
            }
        }
    }

    component NotesViewContainer : Item {
        id: viewRoot
        property bool isFloating: false
        anchors.fill: parent

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
                    color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" 
                }
                
                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 12
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: detachActionButton
                        width: 54
                        height: 24
                        radius: 0
                        color: viewRoot.isFloating ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") : "transparent"
                        border.width: 1
                        border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"

                        Text {
                            anchors.centerIn: parent
                            text: viewRoot.isFloating ? "Attach" : "Detach"
                            font.family: "Rubik"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                        }

                        MouseArea {
                            id: detachMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onClicked: {
                                if (viewRoot.isFloating) {
                                    notesRoot.isDetachedElsewhere = false;
                                    detachedWin.destroy();
                                    notesRoot.openMenu(); 
                                } else {
                                    notesRoot.detachModule();
                                }
                            }
                        }
                    }

                    RowLayout {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: notesRoot.isAlwaysVisible ? "keep" : "keep_off"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 18
                            Layout.alignment: Qt.AlignVCenter
                            color: notesRoot.isAlwaysVisible 
                                ? (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") 
                                : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
                        }

                        Rectangle {
                            width: 50
                            height: 24
                            radius: 12
                            color: notesRoot.isAlwaysVisible 
                                ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") 
                                : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                            
                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                color: rootScope.theme ? rootScope.theme.theme_onPrimary : "#11111b"
                                anchors.verticalCenter: parent.verticalCenter
                                x: notesRoot.isAlwaysVisible ? 28 : 4
                                
                                Behavior on x { 
                                    NumberAnimation { duration: 120; easing.type: Easing.OutQuad } 
                                }
                            }
                            
                            MouseArea {
                                id: btnMouseArea
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (viewRoot.isFloating) {
                                        detachedWin.isAlwaysVisibleState = !detachedWin.isAlwaysVisibleState;
                                        notesRoot.isAlwaysVisible = detachedWin.isAlwaysVisibleState;
                                    } else {
                                        if (notesRoot.isAlwaysVisible) {
                                            notesRoot.menuOpen = true;
                                            notesRoot.isAlwaysVisible = false;
                                            rootScope.requestOpen("notes");
                                        } else {
                                            notesRoot.isAlwaysVisible = true;
                                            notesRoot.menuOpen = false;
                                            rootScope.dismissAll();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff" }

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
                        color: hBar.hovered || hBar.pressed ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff")
                        radius: 0
                    }

                    background: Rectangle {
                        implicitHeight: 5
                        color: "transparent"
                    }
                }

                MouseArea {
                    parent: tabScrollView.contentItem
                    width: Math.max(tabRow.width, tabScrollView.width)
                    height: tabScrollView.height
                    propagateComposedEvents: true
                    
                    onWheel: (wheel) => {
                        if (wheel.angleDelta.y > 0 || wheel.angleDelta.x > 0) {
                            tabScrollView.ScrollBar.horizontal.decrease();
                        } else {
                            tabScrollView.ScrollBar.horizontal.increase();
                        }
                    }
                }

                Row {
                    id: tabRow
                    spacing: 6
                    width: implicitWidth

                    Rectangle {
                        width: 26
                        height: 26
                        color: addMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"
                        border.width: 1
                        border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
                        radius: 0

                        Text {
                            anchors.centerIn: parent
                            text: "add"
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 16
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
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

                    Repeater {
                        id: notesRepeater
                        model: notesRoot.notesList
                        delegate: Rectangle {
                            width: tabText.implicitWidth + 36
                            height: 26
                            color: notesRoot.activeIndex === index ? (rootScope.theme ? rootScope.theme.theme_outline : "#45ffffff") : (tabMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent")
                            border.width: notesRoot.activeIndex === index ? 0 : 1
                            border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
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
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            }

                            Text {
                                id: closeIcon
                                anchors.right: parent.right
                                anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                text: "close"
                                font.family: "Material Symbols Outlined"
                                font.pixelSize: 12
                                color: closeTabMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_fg : "#ffffff") : (rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff")
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
                color: "transparent"
                border.color: rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff"
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
                        color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
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

    Component {
        id: detachedWindowWrapper
        
        PanelWindow {
            id: detachedWin
            
            WlrLayershell.layer: isAlwaysVisibleState ? WlrLayer.Overlay : WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-detached-note"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            
            mask: detachedFrameBounds

            Region {
                id: detachedFrameBounds
                item: detachedFrame
            }
            
            property var passedNotesList: [""]
            property int passedActiveIndex: 0
            property bool passedAlwaysVisible: false
            
            property int spawnX: 10
            property bool isAlwaysVisibleState: passedAlwaysVisible

            Component.onCompleted: {
                notesRoot.notesList = passedNotesList;
                notesRoot.activeIndex = passedActiveIndex;
                notesRoot.isAlwaysVisible = passedAlwaysVisible;
                
                detachedFrame.posX = spawnX;
            }

            Rectangle {
                id: detachedFrame
                
                property int posX: 10
                property int posY: 100
                property bool initialized: false 

                x: posX
                y: posY
                width: 400
                height: 300
                color: "#9911111b"
                
                NotesViewContainer {
                    isFloating: true
                }

                Connections {
                    target: detachedWin
                    
                    function onHeightChanged() {
                        if (!detachedFrame.initialized && detachedWin.height > 0) {
                            detachedFrame.posY = detachedWin.height - detachedFrame.height - 12;
                            detachedFrame.initialized = true;
                        }
                    }
                }

                MouseArea {
                    id: internalFrameDrag
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    cursorShape: containsMouse ? Qt.SizeAllCursor : Qt.ArrowCursor
                    z: -2 

                    property int clickOffsetX: 0
                    property int clickOffsetY: 0

                    onPressed: (mouse) => {
                        clickOffsetX = mouse.x
                        clickOffsetY = mouse.y
                    }

                    onPositionChanged: (mouse) => {
                        if (pressed) {
                            detachedFrame.posX = detachedFrame.posX + mouse.x - clickOffsetX
                            detachedFrame.posY = detachedFrame.posY + mouse.y - clickOffsetY
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: notesHitbox
        anchors.fill: parent
        color: "transparent"
        radius: 0
        opacity: notesRoot.isDetachedElsewhere ? 0.3 : 1.0
        visible: !notesRoot.isDetachedInstance 

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "description" 
                font.family: "Material Symbols Outlined"
                font.pixelSize: 20
                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
            }
        }

        Rectangle {
            id: notesHoverOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: notesMouseArea.containsMouse && !notesRoot.isDetachedElsewhere ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: notesMouseArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton 
            cursorShape: notesRoot.isDetachedElsewhere ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: toggleMenu()
        }
    }

    PanelWindow {
        id: notesOverlayModal
        visible: !notesRoot.isDetachedElsewhere && (notesRoot.menuOpen || notesRoot.isAlwaysVisible)
        color: "transparent"
        
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-overlay"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

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
            onClicked: {
                closeMenu();
                if (rootScope.activeModal === "notes") {
                    rootScope.dismissAll();
                }
            }
        }

        Rectangle {
            id: popupMenuFrame
            height: 300
            
            x: 0
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            
            color: "#9911111b"
            border.width: 0
            radius: 0
            focus: true
            clip: true

            states: [
                State {
                    name: "visible"
                    when: !notesRoot.isDetachedElsewhere && (notesRoot.menuOpen || notesRoot.isAlwaysVisible)
                    PropertyChanges { target: popupMenuFrame; width: 400; opacity: 1.0 }
                },
                State {
                    name: "hidden"
                    when: notesRoot.isDetachedElsewhere || (!notesRoot.menuOpen && !notesRoot.isAlwaysVisible)
                    PropertyChanges { target: popupMenuFrame; width: 0; opacity: 0.0 }
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
                            NumberAnimation { property: "opacity"; duration: Config.exitDuration; easing.type: Config.exitEasing }
                        }
                    }
                }
            ]

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape && !notesRoot.isAlwaysVisible) {
                    closeMenu();
                    if (rootScope.activeModal === "notes") {
                        rootScope.dismissAll();
                    }
                    event.accepted = true;
                }
            }

            MouseArea {
                id: mainContentArea
                anchors.fill: parent
                hoverEnabled: true
                onPressed: (mouse) => { mouse.accepted = true; }
                
                onEntered: dismissTimer.stop()
                onExited: {
                    if (!notesRoot.isAlwaysVisible && notesRoot.menuOpen) {
                        dismissTimer.restart();
                    }
                }

                Item {
                    id: textContentGroup
                    anchors.fill: parent
                    opacity: popupMenuFrame.width > Config.contentFadeThreshold ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    NotesViewContainer {
                        isFloating: false
                    }
                }
            }
        }
    }
}
