import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: cavaVisualizer
    width: visible ? 32 : 0
    height: visible ? 40 : 0
    
    property var barHeights: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var themeContext: null

    visible: {
        for (var i = 0; i < barHeights.length; i++) {
            if (barHeights[i] > 0) return true;
        }
        return false;
    }

    Process {
        id: cavaProcess
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/quickshell_bar.conf"]
        running: true
        
        // Handles data splitting by line immediately, avoiding memory build-up over time
        stdout: SplitParser {
            onRead: (line) => {
                var cleanLine = line.trim();
                if (!cleanLine) return;

                var rawValues = cleanLine.split(';');
                if (rawValues.length >= 10) {
                    var parsedHeights = [];
                    for (var i = 0; i < 10; i++) {
                        var val = parseInt(rawValues[i]) || 0;
                        parsedHeights.push(val / 100.0);
                    }
                    cavaVisualizer.barHeights = parsedHeights;
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 2
        
        Repeater {
            model: 10
            delegate: Rectangle {
                height: 2
                anchors.left: parent.left
                width: cavaVisualizer.barHeights[index] * parent.width
                radius: 0
                color: cavaVisualizer.themeContext ? cavaVisualizer.themeContext.theme_primary : "#ffffff"

                Behavior on width {
                    NumberAnimation { duration: 35; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
