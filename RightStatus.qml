import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

RowLayout {
    id: statusModuleRoot
    spacing: 6 
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignVCenter

    // Bluetooth Plugin Component Instance
    BluetoothOsd {
        Layout.alignment: Qt.AlignVCenter
    }

    // Native Quickshell Notification Component Instance
    NotificationOsd {
        Layout.alignment: Qt.AlignVCenter
    }

    // Clean Split Clock/Calendar Component Instance
    CalendarModule {
        Layout.alignment: Qt.AlignVCenter
    }

    // Clean Split WirePlumber Audio Controller Instance
    AudioModule {
        Layout.alignment: Qt.AlignVCenter
    }
}