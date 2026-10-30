import QtQuick
import QtQuick.Layouts
import "../../kit"

// Design category: the user-tunable tokens.
//
// Ranges come from kit/tokens.js, so a token never hardcodes its slider bounds
// in the UI. Typography is a scale over the base size.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string tab: "shape"

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        VitrailTabs {
            Layout.fillWidth: true
            tabs: [
                { key: "shape", label: page.t("design.section.shape") },
                { key: "surface", label: page.t("section.surface") },
                { key: "type", label: page.t("design.section.type") },
                { key: "share", label: page.t("design.section.share") }
            ]
            current: page.tab
            foreground: page.palette.foreground
            accent: page.palette.primary
            onSelected: page.tab = key
        }

        Flickable {
            id: scroller

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: column.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: column

                width: parent.width
                spacing: VitrailTokens.gap("xl")

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "shape"
                    icon: "straighten"
                    title: page.t("design.section.shape")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("design.spacing")
                        suffix: " px"
                        from: VitrailTokens.ranges.spacing.min
                        to: VitrailTokens.ranges.spacing.max
                        stepSize: VitrailTokens.ranges.spacing.step
                        value: page.prefs.spacing
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.spacing = value
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("design.radius")
                        suffix: " px"
                        from: VitrailTokens.ranges.radius.min
                        to: VitrailTokens.ranges.radius.max
                        stepSize: VitrailTokens.ranges.radius.step
                        value: page.prefs.radius
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.radius = value
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "surface"
                    icon: "layers"
                    title: page.t("section.surface")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("design.blur")
                        from: VitrailTokens.ranges.blur.min
                        to: VitrailTokens.ranges.blur.max
                        stepSize: VitrailTokens.ranges.blur.step
                        value: page.prefs.blurStrength
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.blurStrength = value
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("design.opacity")
                        suffix: "%"
                        from: VitrailTokens.ranges.opacity.min * 100
                        to: VitrailTokens.ranges.opacity.max * 100
                        stepSize: VitrailTokens.ranges.opacity.step * 100
                        value: page.prefs.surfaceOpacity * 100
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.surfaceOpacity = value / 100
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "type"
                    icon: "text_fields"
                    title: page.t("design.section.type")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("design.fontBase")
                        suffix: " px"
                        from: VitrailTokens.font.min
                        to: VitrailTokens.font.max
                        stepSize: VitrailTokens.font.step
                        value: page.prefs.fontBase
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.fontBase = value
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.t("design.scale")
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                        wrapMode: Text.WordWrap
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "share"
                    icon: "share"
                    title: page.t("design.section.share")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    Text {
                        Layout.fillWidth: true
                        text: page.t("design.share")
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
