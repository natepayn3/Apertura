import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: cavaVisualizer
    width: 32
    height: 40
    property var barHeights: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var themeContext: null

    Process {
        id: cavaProcess
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/quickshell_bar.conf"]
        running: true
        
        stdout: StdioCollector {
            waitForEnd: false
            onTextChanged: {
                var lines = text.split('\n');
                if (lines.length < 2) return;
                var lastCompleteLine = lines[lines.length - 2];
                var rawValues = lastCompleteLine.trim().split(';');
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
                width: Math.max(2, cavaVisualizer.barHeights[index] * parent.width)
                radius: 1
                color: cavaVisualizer.themeContext ? cavaVisualizer.themeContext.theme_primary : "#ffffff"

                Behavior on width {
                    NumberAnimation { duration: 35; easing.type: Easing.OutQuad }
                }
            }
        }
    }
}
