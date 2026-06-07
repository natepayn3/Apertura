import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: mediaControlRoot
    width: 32
    height: 32

    readonly property var activePlayer: {
        let playersList = Mpris.players.values;
        if (!playersList || playersList.length === 0) return null;
        
        for (let i = 0; i < playersList.length; i++) {
            let currentPlayer = playersList[i];
            if (currentPlayer && currentPlayer.playbackState === MprisPlaybackState.Playing) {
                return currentPlayer;
            }
        }
        return playersList[0];
    }
    
    function togglePlayback() {
        if (!activePlayer) return;
        
        if (activePlayer.playbackState === MprisPlaybackState.Playing) {
            if (activePlayer.canPause) {
                activePlayer.pause();
            }
        } else {
            if (activePlayer.canPlay) {
                activePlayer.play();
            }
        }
    }

    Rectangle {
        id: visualBase
        anchors.fill: parent
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: {
                if (!mediaControlRoot.activePlayer) return "music_off";
                return mediaControlRoot.activePlayer.playbackState === MprisPlaybackState.Playing 
                    ? "motion_photos_paused" 
                    : "motion_play";
            }
            font.family: "Material Symbols Outlined"
            font.pixelSize: 20
            color: {
                if (!mediaControlRoot.activePlayer) {
                    return rootScope.theme ? rootScope.theme.theme_outline : "#555555";
                }
                return rootScope.theme ? rootScope.theme.theme_fg : "#ffffff";
            }
        }

        Rectangle {
            id: interactionOverlay
            anchors.fill: parent
            radius: 0
            color: rootScope.theme ? rootScope.theme.theme_primary : "#89b4fa"
            opacity: moduleHitbox.containsMouse ? 0.3 : 0.0
            z: 1
        }

        MouseArea {
            id: moduleHitbox
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: mediaControlRoot.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: Qt.LeftButton

            onClicked: {
                mediaControlRoot.togglePlayback();
            }
        }
    }
}
