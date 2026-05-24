import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pam

PanelWindow {
    id: lockWindow

    // 🖥️ BIND TO BASE SCREEN ARRAY
    screen: Quickshell.screens

    // 📐 GLOBAL COORDINATE STRETCH
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    
    WlrLayershell.margins.top: 0
    WlrLayershell.margins.bottom: 0
    WlrLayershell.margins.left: 0
    WlrLayershell.margins.right: 0

    color: "#11111b" 

    // 👑 HYPRLAND SYSTEM EXCLUSIVE OVERRIDE
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusionMode: WlrExclusionMode.None
    
    // 🛠️ THE CRITICAL FIX: Changing this namespace to exactly "lockscreen" triggers Hyprland's full-screen bypass rule
    WlrLayershell.namespace: "lockscreen"

    property string passwordBuffer: ""

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

    onVisibleChanged: {
        if (visible) {
            passwordInput.forceActiveFocus();
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        Text {
            text: "󰌾"
            font.family: "Rubik"
            font.pixelSize: 64
            color: "#cdd6f4"
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: Quickshell.env("USER") ? Quickshell.env("USER").toUpperCase() : "AUTHENTICATION REQUIRED"
            font.family: "Rubik"
            font.pixelSize: 18
            font.bold: true
            color: "#a6adc8"
            Layout.alignment: Qt.AlignHCenter
        }

        Rectangle {
            width: 260
            height: 40
            color: "#1e1e2e"
            radius: 8
            border.width: passwordInput.activeFocus ? 1 : 0
            border.color: "#b4befe"
            Layout.alignment: Qt.AlignHCenter

            TextField {
                id: passwordInput
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                
                font.family: "Rubik"
                font.pixelSize: 14
                color: "#cdd6f4"
                echoMode: TextInput.Password
                passwordCharacter: "•"
                
                background: null
                focus: true

                placeholderText: "Enter Password..."
                placeholderTextColor: "#6c7086"

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
            font.pixelSize: 13
            font.bold: true
            color: text === "Authenticating..." ? "#a6e3a1" : "#f38ba8"
            Layout.alignment: Qt.AlignHCenter
        }
    }
}