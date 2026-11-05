import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../kit"
import "../kit/base"

// The dashboard's month, with today in the accent circle. The same component
// draws the desktop calendar; the caller owns the shown month so it can page.
ColumnLayout {
    id: root

    property date now: new Date()
    property date shown: new Date()
    property string language: "en"
    property string size: "md"
    property string variant: ""

    signal pageRequested(int step)
    signal todayRequested()

    spacing: VitrailTokens.gap("md")

    readonly property var look: ({
        sm: { title: "body", day: "label" },
        md: { title: "body", day: "content" },
        lg: { title: "subtitle", day: "body" }
    })[root.size] || ({ title: "body", day: "content" })
    readonly property real cell: VitrailTokens.size("display") + VitrailTokens.gap("xs")

    function monthTitle() {
        var text = root.shown.toLocaleDateString(Qt.locale(root.language), "MMMM yyyy")
        return text.charAt(0).toUpperCase() + text.slice(1)
    }

    function showingThisMonth() {
        return root.shown.getMonth() === root.now.getMonth()
               && root.shown.getFullYear() === root.now.getFullYear()
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: VitrailTokens.gap("xs")
        visible: root.variant !== "compact"

        VitrailText {
            Layout.fillWidth: true
            variant: root.look.title
            font.weight: Font.DemiBold
            text: root.monthTitle()
        }

        VitrailButton {
            visible: !root.showingThisMonth()
            variant: "text"
            size: "sm"
            text: root.todayText
            onClicked: root.todayRequested()
        }

        VitrailButton {
            variant: "plain"
            tone: "secondary"
            icon: "chevron_left"
            onClicked: root.pageRequested(-1)
        }

        VitrailButton {
            variant: "plain"
            tone: "secondary"
            icon: "chevron_right"
            onClicked: root.pageRequested(1)
        }
    }

    DayOfWeekRow {
        Layout.fillWidth: true
        locale: Qt.locale(root.language)

        delegate: VitrailText {
            required property string shortName

            horizontalAlignment: Text.AlignHCenter
            variant: "label"
            text: shortName.charAt(0).toUpperCase() + shortName.slice(1, 2)
        }
    }

    MonthGrid {
        Layout.fillWidth: true
        locale: Qt.locale(root.language)
        month: root.shown.getMonth()
        year: root.shown.getFullYear()

        delegate: Item {
            id: day

            required property var model

            readonly property bool today: day.model.today
            readonly property bool inMonth: day.model.month === root.shown.getMonth()

            implicitWidth: root.cell
            implicitHeight: root.cell

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                radius: width / 2
                visible: day.today
                color: VitrailTokens.color("primary")
            }

            VitrailText {
                anchors.centerIn: parent
                variant: root.look.day
                font.features: ({ "tnum": 1 })
                font.weight: day.today ? Font.DemiBold : Font.Normal
                opacity: day.inMonth ? 1 : 0.35
                color: day.today ? VitrailTokens.color("accentForeground")
                                 : VitrailTokens.color("foreground")
                text: day.model.day
            }
        }
    }

    // The dashboard's i18n key; the desktop host sets it too.
    property string todayText: "Today"
}
