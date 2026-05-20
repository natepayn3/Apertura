import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: contentRoot
    property string activeSection: "Notifications"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 24

        Text {
            text: contentRoot.activeSection
            font.family: "Rubik, sans-serif"
            font.pixelSize: 28
            font.weight: Font.Bold
            color: "#cdd6f4"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 18

            Text {
                text: "APPEARANCE"
                font.family: "Rubik, sans-serif"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: "#f38ba8"
                Layout.bottomMargin: 4
            }

            CustomSettingsSlider { label: "Item Height"; defaultValue: 60; maxValue: 100 }
            CustomSettingsSlider { label: "Icon Size"; defaultValue: 36; maxValue: 64 }
            CustomSettingsSlider { label: "Spacing"; defaultValue: 4; maxValue: 20 }
            CustomSettingsSlider { label: "Opacity"; defaultValue: 0.04; maxValue: 1.0 }
        }

        // Native QML Layout Spring replacement for Spacer
        Item { 
            Layout.fillHeight: true 
        }
    }
}