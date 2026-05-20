import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RowLayout {
    Layout.fillWidth: true
    spacing: 20

    property string label: ""
    property real defaultValue: 0
    property real maxValue: 100

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: label
                font.family: "Rubik"
                font.pixelSize: 13
                color: "#cdd6f4"
            }
            
            Spacer { Layout.fillWidth: true }
            
            Text {
                text: systemSlider.value.toFixed(label === "Opacity" ? 2 : 0)
                font.family: "Rubik"
                font.pixelSize: 13
                color: "#6c7086"
            }
        }

        // Custom Slider Track Blueprint
        Slider {
            id: systemSlider
            Layout.fillWidth: true
            from: 0
            to: maxValue
            value: defaultValue

            background: Rectangle {
                x: systemSlider.leftPadding
                y: systemSlider.topPadding + systemSlider.availableHeight / 2 - height / 2
                implicitWidth: 200
                implicitHeight: 4
                width: systemSlider.availableWidth
                height: implicitHeight
                radius: 2
                color: "#313244"

                Rectangle {
                    width: systemSlider.visualPosition * parent.width
                    height: parent.height
                    color: "#f5e0dc" // Accent track layer highlight
                    radius: 2
                }
            }

            handle: Rectangle {
                x: systemSlider.leftPadding + systemSlider.visualPosition * (systemSlider.availableWidth - width)
                y: systemSlider.topPadding + systemSlider.availableHeight / 2 - height / 2
                implicitWidth: 14
                implicitHeight: 14
                radius: 7
                color: "#ffffff"
                border.color: "#f5e0dc"
                border.width: 1
            }
        }
    }
}