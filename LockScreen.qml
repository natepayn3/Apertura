import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects // 🛠️ Crucial for native hardware blur effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam

PanelWindow {
    id: lockWindow

    required property var lockScreenTarget
    screen: lockScreenTarget

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
    WlrLayershell.margins.top: 0
    WlrLayershell.margins.bottom: 0
    WlrLayershell.margins.left: 0
    WlrLayershell.margins.right: 0

    // Set a solid background color globally to ensure visibility across all displays
    color: "#11111b"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "lockscreen"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    property string passwordBuffer: ""
    property var currentDateTime: new Date()

    Timer {
        id: lockClockTicker
        interval: 1000
        running: true
        repeat: true
        onTriggered: lockWindow.currentDateTime = new Date()
    }

    PamContext {
        id: pamDriver
        config: "login" 

        onCompleted: (result) => {
            if (result === PamResult.Success) {
                passwordInput.text = "";
                lockWindow.passwordBuffer = "";
                errorText.text = "";
                rootScope.sessionLocked = false;
            } else {
                errorText.text = "Authentication Failed";
                passwordInput.text = "";
                lockWindow.passwordBuffer = "";
                passwordInput.forceActiveFocus();
            }
        }

        onPamMessage: {
            if (pamDriver.responseRequired) {
                pamDriver.respond(lockWindow.passwordBuffer);
            }
        }
    }

    Component.onCompleted: {
        if (lockScreenTarget && lockScreenTarget.primary) {
            passwordInput.forceActiveFocus();
        }
    }

    onVisibleChanged: {
        if (visible && lockScreenTarget && lockScreenTarget.primary) {
            passwordInput.forceActiveFocus();
        }
    }

    // ==========================================
    // 🎨 NATIVE VISUAL BACKGROUND (PRIMARY ONLY)
    // ==========================================
    // This loads your wallpaper file directly and runs a heavy blur shader pass on it
    Item {
        anchors.fill: parent
        visible: lockScreenTarget ? lockScreenTarget.primary : false

        Image {
            id: bgSource
            anchors.fill: parent
            // Points to your wallpaper file or a cache file
            source: "file://" + Quickshell.env("HOME") + "/.config/background" 
            fillMode: Image.PreserveAspectCrop
            visible: false // Hidden because the blur effect element handles the draw loop
        }

        FastBlur {
            anchors.fill: parent
            source: bgSource
            radius: 64 // Smooth frosted appearance
            
            // Subtle dark overlay tint so your white text remains sharp and legible
            Rectangle {
                anchors.fill: parent
                color: "#000000"
                opacity: 0.4
            }
        }
    }

    // ==========================================
    // 📋 RICED AUTHENTICATION USER INTERFACE
    // ==========================================
    ColumnLayout {
        id: authFormContainer
        visible: lockScreenTarget ? lockScreenTarget.primary : false
        anchors.centerIn: parent
        spacing: 28
        z: 1

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Text {
                text: Qt.formatDateTime(lockWindow.currentDateTime, "h:mm")
                font.family: "Rubik"
                font.pixelSize: 150
                font.weight: Font.ExtraBold
                color: "#cdd6f4" 
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: Qt.formatDateTime(lockWindow.currentDateTime, "dddd, MMMM d")
                font.family: "Rubik"
                font.pixelSize: 30
                font.weight: Font.Medium
                color: "#f5c2e7" 
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Item { Layout.preferredHeight: 10 }

        Rectangle {
            width: 320
            height: 56
            color: "#1e1e2e"
            radius: 12
            border.width: passwordInput.activeFocus ? 1 : 0
            border.color: "#b4befe"
            Layout.alignment: Qt.AlignHCenter

            TextField {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 12
                
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                
                font.family: "Rubik"
                font.pixelSize: 28
                color: "#cdd6f4"
                echoMode: TextInput.Password
                passwordCharacter: "●"
                font.letterSpacing: 6
                
                background: null

                placeholderText: ""
                placeholderTextColor: "#585b70"

                onAccepted: {
                    if (text.length > 0) {
                        errorText.text = "Authenticating...";
                        lockWindow.passwordBuffer = text;
                        pamDriver.start();
                    }
                }
            }
        }

        Text {
            id: errorText
            text: ""
            font.family: "Rubik"
            font.pixelSize: 20
            font.weight: Font.Bold
            color: text === "Authenticating..." ? "#a6e3a1" : "#f38ba8" 
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
