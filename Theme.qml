import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: theme

    property string configPath: Quickshell.env("HOME") + "/.config/quickshell/Apertura/Colors/colors.json"

    property color theme_bg: "#9911111b"
    property color theme_primary: "#ffffff"
    property color theme_onPrimary: "#11111b"
    property color theme_fg: "#ffffff"
    property color theme_outline: "#26ffffff"

    FileView {
        id: colorConfigReader
        path: theme.configPath
        preload: true

        onTextChanged: {
            try {
                let rawText = text();
                if (rawText && rawText.trim() !== "") {
                    let parsed = JSON.parse(rawText);
                    if (parsed && parsed.colors) {
                        
                        if (parsed.colors.background && parsed.colors.background.dark && parsed.colors.background.dark.color)
                            theme.theme_bg = parsed.colors.background.dark.color;
                            
                        if (parsed.colors.primary && parsed.colors.primary.dark && parsed.colors.primary.dark.color)
                            theme.theme_primary = parsed.colors.primary.dark.color;
                            
                        if (parsed.colors.on_primary && parsed.colors.on_primary.dark && parsed.colors.on_primary.dark.color)
                            theme.theme_onPrimary = parsed.colors.on_primary.dark.color;
                            
                        if (parsed.colors.on_surface && parsed.colors.on_surface.dark && parsed.colors.on_surface.dark.color)
                            theme.theme_fg = parsed.colors.on_surface.dark.color;
                            
                        if (parsed.colors.outline && parsed.colors.outline.dark && parsed.colors.outline.dark.color)
                            theme.theme_outline = parsed.colors.outline.dark.color;
                    }
                }
            } catch (e) {
                console.log("❌ FileView Processing Exception: " + e);
            }
        }
    }

    // Explicitly forces the FileView engine to discard cache and read disk bytes
    function reloadTheme() {
        colorConfigReader.reload();
    }
}
