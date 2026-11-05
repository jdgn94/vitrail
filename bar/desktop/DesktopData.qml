import QtQuick
import Quickshell
import Quickshell.Io
import "../dashboard/dashboard.js" as Dash

// The desktop widgets' data: the weather and the machine's readings, shared by
// every monitor's layer. It runs only while at least one desktop widget exists,
// so an empty desktop costs nothing.
Item {
    id: root

    property bool active: false
    property var weather: ({})
    property var resources: ({})

    implicitWidth: 0
    implicitHeight: 0

    function refreshWeather() {
        if (!weatherProcess.running)
            weatherProcess.running = true
    }

    function refreshResources() {
        if (!resourcesProcess.running)
            resourcesProcess.running = true
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.refreshResources()
    }

    Timer {
        interval: 900000
        repeat: true
        running: root.active
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
}
