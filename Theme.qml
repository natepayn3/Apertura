import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: theme

    property string configPath: Quickshell.home + "/.config/matugen/templates/colors.json"
    property var colors: null

    Process {
        id: reader
        command: ["cat", theme.configPath]
        running: true
        stdout: StdioCollector {
            onTextChanged: {
                try {
                    theme.colors = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    function getColor(key, fallback) {
        if (colors && colors.colors && colors.colors[key] && colors.colors[key].dark) {
            return colors.colors[key].dark.color
        }
        return fallback
    }

    property color bg: colors ? getColor("background", "#9911111b") : "#9911111b"
    property color primary: colors ? getColor("primary", "#ffffff") : "#ffffff"
    property color onPrimary: colors ? getColor("on_primary", "#11111b") : "#11111b"
    property color text: colors ? getColor("on_surface", "#ffffff") : "#ffffff"
    property color outline: colors ? getColor("outline", "#26ffffff") : "#26ffffff"
}
