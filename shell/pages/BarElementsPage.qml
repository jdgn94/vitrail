import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"

// Bar elements category: per-element settings for every new-style bar element.
// Elements shipped with Vitrail appear here with their own options; the sample
// element is the reference implementation.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string tab: ""

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("xl")

            Section {
                Layout.fillWidth: true
                title: page.t("bar.elements.sampleItem")
            }

            VitrailSettingRow {
                Layout.fillWidth: true
                label: page.t("bar.elements.showMode")
                foreground: page.palette.foreground
                muted: page.palette.muted

                VitrailSegmented {
                    options: [
                        { key: "always", label: page.t("bar.elements.showMode.always") },
                        { key: "active", label: page.t("bar.elements.showMode.active") }
                    ]
                    current: page.prefs.sampleShowMode || "always"
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onSelected: function (key) { page.prefs.sampleShowMode = key }
                }
            }

            Item { Layout.preferredHeight: VitrailTokens.gap("xl") }
        }
    }
}
