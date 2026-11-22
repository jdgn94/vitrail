import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/elements.js" as Elements

// One bar element's block in Settings → Bar elements: its glyph and title, the
// "only while active" switch every element has, and (as children) its own
// options. `elementId` is the element's id in bar/widgets.js and the tab its
// popup's gear opens; the glyph is the registry's and the block's row on the
// page comes from its group (bar/elements.js PAGE_GROUPS).
Section {
    id: section

    property string elementId: ""
    property var palette
    property var prefs
    property var strings

    readonly property var activeOnly: Elements.activeOnly(section.prefs.barActiveOnly)

    function t(key) {
        var value = section.strings[key]
        return value === undefined ? key : value
    }

    Layout.row: Elements.pageRow(section.elementId)
    icon: Elements.icon(section.elementId)
    title: section.t("bar.widget." + section.elementId)
    foreground: section.palette.foreground
    accent: section.palette.primary

    VitrailSettingRow {
        Layout.fillWidth: true
        label: section.t("bar.elements.showMode")
        foreground: section.palette.foreground
        muted: section.palette.muted

        VitrailSegmented {
            objectName: "showMode"
            options: [
                { key: "always", label: section.t("bar.elements.showMode.always") },
                { key: "active", label: section.t("bar.elements.showMode.active") }
            ]
            current: Elements.showMode(section.activeOnly, section.elementId)
            foreground: section.palette.foreground
            accent: section.palette.primary
            onSelected: function (key) {
                section.prefs.barActiveOnly = Elements.withShowMode(section.activeOnly, section.elementId, key)
            }
        }
    }
}
