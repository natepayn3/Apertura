pragma Singleton
import QtQuick

QtObject {
    // Drawer defaults
    readonly property int drawerTargetWidth: 300
    readonly property int entryDuration: 350
    readonly property int exitDuration: 350
    readonly property int entryEasing: Easing.OutCubic
    readonly property int exitEasing: Easing.InCubic
    
    // OSD and System timings
    readonly property int autohideInterval: 3500
    readonly property int contentFadeThreshold: 250
}
