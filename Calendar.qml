import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "."

Item {
    id: calendarRoot

    implicitWidth: clockHitbox.width
    implicitHeight: clockHitbox.height

    property bool menuOpen: false
    property date currentDateTime: new Date()
    
    readonly property date baseDate: new Date()
    property int currentMonthOffsetIndex: 50
    property date viewerTargetDate: new Date()

    // Location override option for VPN users. Examples: "90210", "London"
    // Leave blank ("") to fallback to automated dynamic IP location detection.
    property string weatherLocationOverride: ""

    property string weatherTemp: "--"
    property string weatherFeelsLike: "--"
    property string weatherDesc: "Loading..."
    property string weatherGlyph: "cloud"

    readonly property var weatherIconMap: {
        "0": "clear_day",
        "1": "partly_cloudy_day",
        "2": "partly_cloudy_day",
        "3": "cloudy",
        "45": "foggy",
        "48": "foggy",
        "51": "rainy",
        "53": "rainy",
        "55": "rainy",
        "61": "rainy",
        "63": "rainy",
        "65": "rainy",
        "71": "snowing",
        "73": "snowing",
        "75": "snowing",
        "77": "snowing",
        "80": "rainy",
        "81": "rainy",
        "82": "rainy",
        "85": "snowing",
        "86": "snowing",
        "95": "thunderstorm",
        "96": "thunderstorm",
        "99": "thunderstorm"
    }

    readonly property var weatherDescMap: {
        "0": "Clear Sky", "1": "Mainly Clear", "2": "Partly Cloudy", "3": "Overcast",
        "45": "Foggy", "48": "Rime Fog", "51": "Light Drizzle", "53": "Moderate Drizzle",
        "55": "Dense Drizzle", "61": "Slight Rain", "63": "Moderate Rain", "65": "Heavy Rain",
        "71": "Light Snow", "73": "Moderate Snow", "75": "Heavy Snow", "77": "Snow Grains",
        "80": "Light Showers", "81": "Moderate Showers", "82": "Heavy Showers",
        "85": "Light Snow Showers", "86": "Heavy Snow Showers", "95": "Thunderstorm",
        "96": "Storm w/ Hail", "99": "Severe Storm"
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: calendarRoot.currentDateTime = new Date()
    }

    Timer {
        id: osdAutohideTimer; interval: Config.autohideInterval; running: false; repeat: false
        onTriggered: closeMenu()
    }

    Timer {
        id: weatherTimer
        interval: 900000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: startWeatherPipeline()
    }

    Process {
        id: weatherFetcher
        command: ["curl", "-s", "https://wttr.is/" + calendarRoot.weatherLocationOverride.trim() + "?format=j1"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text);
                    let current = data.current_condition[0];
                    
                    calendarRoot.weatherTemp = current.temp_F + "°F";
                    calendarRoot.weatherFeelsLike = current.FeelsLikeF + "°F";
                    
                    let code = current.weatherCode.toString();
                    calendarRoot.weatherDesc = calendarRoot.weatherDescMap[code] !== undefined ? calendarRoot.weatherDescMap[code] : current.weatherDesc[0].value;
                    calendarRoot.weatherGlyph = calendarRoot.weatherIconMap[code] !== undefined ? calendarRoot.weatherIconMap[code] : "cloud";
                } catch (e) {
                    console.log("Shell stdout parsing exception: " + e);
                }
                weatherFetcher.running = false;
            }
        }
    }

    function startWeatherPipeline() {
        weatherFetcher.running = true;
    }

    function checkUserActivity() {
        if (mainContainerMouseArea.containsMouse) {
            osdAutohideTimer.stop(); 
        } else if (drawerTemplate.isOpen) {
            osdAutohideTimer.restart(); 
        }
    }

    function toggleMenu(): void {
        drawerTemplate.isOpen = !drawerTemplate.isOpen;
    }

    function closeMenu(): void {
        drawerTemplate.isOpen = false;
    }

    function updateViewerDate() {
        let monthOffset = calendarRoot.currentMonthOffsetIndex - 50;
        calendarRoot.viewerTargetDate = new Date(calendarRoot.baseDate.getFullYear(), calendarRoot.baseDate.getMonth() + monthOffset, 1);
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
        id: clockHitbox
        width: 44; height: verticalLayout.implicitHeight + 4
        color: "transparent"
        radius: 0

        ColumnLayout {
            id: verticalLayout; anchors.centerIn: parent; spacing: 0
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "ddd"); font.family: "Rubik"; font.pixelSize: 12; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_outline : "#59ffffff"; Layout.alignment: Qt.AlignHCenter }
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "h:mm ap").replace(/\s*[aApP][mM]\s*/g, ""); font.family: "Rubik"; font.pixelSize: 14; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"; Layout.alignment: Qt.AlignHCenter }
            Text { text: Qt.formatDateTime(calendarRoot.currentDateTime, "ap"); font.family: "Rubik"; font.pixelSize: 10; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"; Layout.alignment: Qt.AlignHCenter }
        }

        Rectangle {
        id: hoverBackground
        anchors.fill: parent
        radius: 0
        color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
        opacity: clockMouseArea.containsMouse ? 0.3 : 0.0
        z: 1 // Ensures it sits above the base but below text
    }

        MouseArea { 
            id: clockMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: toggleMenu() 
        }
    }

    PanelDrawer {
        id: drawerTemplate
        isOpen: false
        drawerHeight: 375 
        modalToken: "calendar"
        anchorTop: true

        onIsOpenChanged: {
            if (isOpen) {
                calendarRoot.menuOpen = true;
                calendarRoot.currentMonthOffsetIndex = 50;
                updateViewerDate();
                checkUserActivity();
                startWeatherPipeline(); 
                mainContainerLayout.forceActiveFocus();
            } else {
                calendarRoot.menuOpen = false;
            }
        }

        MouseArea { anchors.fill: parent; onPressed: (mouse) => { closeMenu(); mouse.accepted = true; } }

        MouseArea {
            id: mainContainerMouseArea
            anchors.fill: parent
            hoverEnabled: true
            propagateComposedEvents: true
            onContainsMouseChanged: checkUserActivity()

            ColumnLayout {
                id: mainContainerLayout
                anchors.fill: parent; anchors.topMargin: 14; anchors.bottomMargin: 14; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 4 
                focus: true

                RowLayout {
                    Layout.fillWidth: true; spacing: 0
                    Rectangle {
                        width: 28; height: 28; color: prevMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"; radius: 6
                        Text { anchors.centerIn: parent; text: "chevron_left"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                        MouseArea { id: prevMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (calendarRoot.currentMonthOffsetIndex > 0) { calendarRoot.currentMonthOffsetIndex--; calendarRoot.updateViewerDate(); } } }
                    }
                    Item { Layout.fillWidth: true }
                    Text { text: Qt.formatDateTime(calendarRoot.viewerTargetDate, "MMMM yyyy"); font.family: "Rubik"; font.pixelSize: 16; font.weight: Font.Bold; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        width: 28; height: 28; color: nextMouse.containsMouse ? (rootScope.theme ? rootScope.theme.theme_outline : "#26ffffff") : "transparent"; radius: 6
                        Text { anchors.centerIn: parent; text: "chevron_right"; font.family: "Material Symbols Outlined"; font.pixelSize: 18; color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff" }
                        MouseArea { id: nextMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { if (calendarRoot.currentMonthOffsetIndex < 100) { calendarRoot.currentMonthOffsetIndex++; calendarRoot.updateViewerDate(); } } }
                    }
                }

                StackLayout {
                    id: calendarDisplayStack; Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: calendarRoot.currentMonthOffsetIndex
                    Repeater {
                        model: 101
                        delegate: Item {
                            readonly property int currentVirtualOffset: index - 50
                            readonly property int resolvedMonthPosition: calendarRoot.baseDate.getMonth() + currentVirtualOffset
                            readonly property date loopCalculatedDate: new Date(calendarRoot.baseDate.getFullYear(), resolvedMonthPosition, 1)

                            MonthGrid {
                                id: grid; anchors.fill: parent; month: parent.loopCalculatedDate.getMonth(); year: parent.loopCalculatedDate.getFullYear(); font.family: "Rubik"; font.pixelSize: 12
                                delegate: Item {
                                    implicitWidth: 32; implicitHeight: 32
                                    readonly property bool isToday: model.day === calendarRoot.currentDateTime.getDate() && model.month === calendarRoot.currentDateTime.getMonth() && model.year === calendarRoot.currentDateTime.getFullYear()
                                    Rectangle { anchors.fill: parent; anchors.margins: 2; color: "transparent"; border.width: parent.isToday ? 2 : 0; border.color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff"; radius: 6 }
                                    Text { anchors.centerIn: parent; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; opacity: model.month === grid.month ? 1.0 : 0.25; text: model.day; color: rootScope.theme ? (parent.isToday ? rootScope.theme.theme_primary : rootScope.theme.theme_fg) : "#ffffff"; font.family: grid.font.family; font.pixelSize: grid.font.pixelSize; font.weight: parent.isToday ? Font.Bold : Font.Normal }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: weatherCardSurface
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            text: calendarRoot.weatherGlyph
                            font.family: "Material Symbols Outlined"
                            font.pixelSize: 26
                            color: rootScope.theme ? rootScope.theme.theme_primary : "#ffffff"
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.alignment: Qt.AlignVCenter
                            Layout.fillWidth: true

                            Text {
                                text: calendarRoot.weatherDesc
                                font.family: "Rubik"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                elide: Text.ElideRight
                            }

                            Text {
                                text: "Feels like " + calendarRoot.weatherFeelsLike
                                font.family: "Rubik"
                                font.pixelSize: 11
                                color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                                opacity: 0.6
                            }
                        }

                        Text {
                            text: calendarRoot.weatherTemp
                            font.family: "Rubik"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                            color: rootScope.theme ? rootScope.theme.theme_fg : "#ffffff"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
