import QtQuick
import Quickshell
import Quickshell.Io
import "../media"
import "."
import "dashboard.js" as Dash

// The dashboard host: runs the two services while the popup is open and keeps
// the content (Dashboard.qml) free of Quickshell, so the content is testable.
//   performance: every 2 s while its tab is shown
//   weather:     every 15 min while its tab is shown (the service caches too)
// Nothing runs while the popup is closed or its tab is not the one on screen.
Item {
    id: root

    property bool open: false
    property var strings: ({})
    property string language: "en"
    property var mediaPlayer: null
    property var mediaPlayers: []
    property int mediaIndex: 0
    property string mediaStyle: "disc"
    // The shell's clock engine: the popup only draws and asks.
    property var timerEngine: null

    signal playerChosen(int index)

    property var weather: ({})
    property var resources: ({})

    implicitWidth: panel.implicitWidth
    implicitHeight: panel.implicitHeight

    function refreshWeather() {
        if (!weatherProcess.running)
            weatherProcess.running = true
    }

    function refreshResources() {
        if (!resourcesProcess.running)
            resourcesProcess.running = true
    }

    Dashboard {
        id: panel

        anchors.fill: parent
        weather: root.weather
        resources: root.resources
        strings: root.strings
        language: root.language
        mediaPlayer: root.mediaPlayer
        mediaPlayers: root.mediaPlayers
        mediaIndex: root.mediaIndex
        mediaStyle: root.mediaStyle
        timerEngine: root.timerEngine
        mediaPanel: mediaComponent
        onPlayerChosen: function (index) { root.playerChosen(index) }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.open && panel.currentTab === "performance"
        triggeredOnStart: true
        onTriggered: root.refreshResources()
    }

    Timer {
        interval: 900000
        repeat: true
        running: root.open && panel.currentTab === "weather"
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }

    Process {
        id: weatherProcess

        command: ["python3", "-m", "vitrail.weather", "state"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: root.weather = Dash.parse(this.text)
        }
    }

    Process {
        id: resourcesProcess

        command: ["python3", "-m", "vitrail.resources", "state"]
        environment: ({ PYTHONPATH: Quickshell.shellDir + "/.." })
        stdout: StdioCollector {
            onStreamFinished: root.resources = Dash.parse(this.text)
        }
    }

    // The media panel lives here, where MPRIS is available; the content only
    // places what it is given.
    Component {
        id: mediaComponent

        MediaPanel {
            player: root.mediaPlayer
            players: root.mediaPlayers
            index: root.mediaIndex
            style: root.mediaStyle
            strings: root.strings
            onPlayerChosen: function (index) { root.playerChosen(index) }
        }
    }
}
