Scope {
    id: rootScope

    property var configurationAsset: Config

    property alias theme: theme 

    property var sharedPinnedApps: []

    Theme { id: theme }

    FileView {
        id: pinCacheReader
        path: Quickshell.env("HOME") + "/.cache/quickshell_launcher_pins.json"
        
        onTextChanged: {
            let cleanText = text().trim();
            if (!cleanText || cleanText === "[]") return;
            try {
                let parsed = JSON.parse(cleanText);
                if (parsed && parsed.pins) {
                    rootScope.sharedPinnedApps = parsed.pins;
                }
            } catch(e) {}
        }
    }

    Component.onCompleted: {
        pinCacheReader.reload();
    }

    property var activeModal: null
    property bool audioSliderActive: false
    property var instantiatedBars: ({})
    property bool sessionLocked: false
