import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: settingsOsd
    screen: Quickshell.screens.primary
    
    // Float directly in the center of the viewport
    anchors {
        top: false
        bottom: false
        left: false
        right: false
    }
    
    // Fixed canvas geometry based on reference layout
    implicitWidth: 800
    implicitHeight: 500
    
    color: "transparent"
    
    // Layer management: Needs to stay on top of regular windows when opened
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusive: false
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Main Control Frame
    Rectangle {
        anchors.fill: parent
        color: "#181825" // Dark base matching image context
        radius: 16
        opacity: 0.96 // Gives a tight, heavy look without full transparency
        
        RowLayout {
            anchors.fill: parent
            spacing: 0

            // Left Side: Sidebar Navigation Tree
            SettingsSidebar {
                id: sidebar
                Layout.preferredWidth: 240
                Layout.fillHeight: true
            }

            // Right Side: Content Variable Split
            SettingsContent {
                Layout.fillWidth: true
                Layout.fillHeight: true
                activeSection: sidebar.currentSection
            }
        }
    }
}