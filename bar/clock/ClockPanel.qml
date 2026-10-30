import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "../kit"
import "../kit/base"

// Clock popup: the time and the date, then a month calendar that starts on
// today and pages by month. Sized to its content.
Item {
    id: root

    property var strings: ({})
    property string language: "en"

    readonly property var locale: Qt.locale(root.language)
    property date shown: new Date()

    implicitWidth: 320
    implicitHeight: body.implicitHeight

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    function page(step) {
        root.shown = new Date(root.shown.getFullYear(), root.shown.getMonth() + step, 1)
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            VitrailText {
                variant: "display"
                font.features: ({ "tnum": 1 })
                text: clock.date.toLocaleTimeString(root.locale, "HH:mm")
            }

            VitrailText {
                Layout.fillWidth: true
                variant: "content"
                text: {
                    var day = clock.date.toLocaleDateString(root.locale, "dddd d MMMM yyyy")
                    return day.charAt(0).toUpperCase() + day.slice(1)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            VitrailText {
                Layout.fillWidth: true
                variant: "body"
                font.weight: Font.DemiBold
                text: {
                    var month = root.shown.toLocaleDateString(root.locale, "MMMM yyyy")
                    return month.charAt(0).toUpperCase() + month.slice(1)
                }
            }

            VitrailButton {
                visible: root.shown.getMonth() !== clock.date.getMonth()
                         || root.shown.getFullYear() !== clock.date.getFullYear()
                variant: "text"
                size: "sm"
                text: root.t("clock.today")
                onClicked: root.shown = new Date()
            }

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                icon: "chevron_left"
                onClicked: root.page(-1)
            }

            VitrailButton {
                variant: "plain"
                tone: "secondary"
                icon: "chevron_right"
                onClicked: root.page(1)
            }
        }

        DayOfWeekRow {
            Layout.fillWidth: true
            locale: root.locale

            delegate: VitrailText {
                required property string shortName

                horizontalAlignment: Text.AlignHCenter
                variant: "label"
                text: shortName.charAt(0).toUpperCase() + shortName.slice(1, 2)
            }
        }

        MonthGrid {
            Layout.fillWidth: true
            locale: root.locale
            month: root.shown.getMonth()
            year: root.shown.getFullYear()

            delegate: Item {
                id: day

                required property var model

                readonly property bool today: day.model.today
                readonly property bool inMonth: day.model.month === root.shown.getMonth()

                implicitWidth: VitrailTokens.size("display") + VitrailTokens.gap("xs")
                implicitHeight: implicitWidth

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
                    variant: "content"
                    font.features: ({ "tnum": 1 })
                    font.weight: day.today ? Font.DemiBold : Font.Normal
                    opacity: day.inMonth ? 1 : 0.35
                    color: day.today ? VitrailTokens.color("accentForeground") : VitrailTokens.color("foreground")
                    text: day.model.day
                }
            }
        }
    }
}
