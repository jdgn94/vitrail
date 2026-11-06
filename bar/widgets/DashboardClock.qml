import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The dashboard's clock: the time and the date. The same component draws the
// desktop clock; `size` and `variant` are the common widget API ("compact"
// keeps only the time).
ColumnLayout {
    id: root

    property date now: new Date()
    property string language: "en"
    property string size: "md"
    property string variant: ""
    // The widget's own typography; empty values keep the variant's look.
    property string fontFamily: ""
    property string fontWeight: ""
    property bool italic: false
    // The dashboard's tests and the desktop host may name the two labels.
    property string clockName: "dashboardClock"
    property string dateName: "dashboardClockDate"

    spacing: 0

    readonly property var look: ({
        sm: { time: "title", date: "label" },
        md: { time: "display", date: "content" },
        lg: { time: "display", date: "body" }
    })[root.size] || ({ time: "display", date: "content" })
    readonly property bool withDate: root.variant !== "compact" && root.variant !== "minimal"
    readonly property string timeVariant: root.variant === "minimal" ? "title" : root.look.time

    VitrailText {
        objectName: root.clockName
        variant: root.timeVariant
        family: root.fontFamily
        fontWeight: root.fontWeight
        italic: root.italic
        font.features: ({ "tnum": 1 })
        text: root.now.toLocaleTimeString(Qt.locale(root.language), "HH:mm")
    }

    VitrailText {
        objectName: root.dateName
        Layout.fillWidth: true
        visible: root.withDate
        variant: root.look.date
        family: root.fontFamily
        fontWeight: root.fontWeight
        italic: root.italic
        text: {
            var day = root.now.toLocaleDateString(Qt.locale(root.language), "dddd d MMMM yyyy")
            return day.charAt(0).toUpperCase() + day.slice(1)
        }
    }
}
