import QtQuick
import QtQuick.Layouts
import "../../kit"

// Windows category: border geometry, window opacity and the tiling layout.
// Three distinct topics, so they stay on tabs (`tab` is also the --tab deep
// link); each tab body is a scrolling Section.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string tab: "border"
    property int screenWidth: 1920

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
                { key: "border", label: page.t("windows.tabBorder") },
                { key: "opacity", label: page.t("windows.tabOpacity") },
                { key: "layout", label: page.t("windows.tabLayout") }
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
                    visible: page.tab === "border"
                    icon: "border_style"
                    title: page.t("windows.tabBorder")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("windows.border")
                        suffix: " px"
                        from: 0
                        to: 6
                        value: page.prefs.borderWidth
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.borderWidth = value
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("windows.radius")
                        suffix: " px"
                        from: 0
                        to: 30
                        value: page.prefs.radius
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.radius = value
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.t("windows.borderHelp")
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                        wrapMode: Text.WordWrap
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "opacity"
                    icon: "opacity"
                    title: page.t("windows.tabOpacity")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("windows.opacityFocused")
                        suffix: "%"
                        from: 0
                        to: 70
                        stepSize: 1
                        value: (1 - page.prefs.opacityFocused) * 100
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.opacityFocused = 1 - value / 100
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("windows.opacityUnfocused")
                        suffix: "%"
                        from: 0
                        to: 70
                        stepSize: 1
                        value: (1 - page.prefs.opacityUnfocused) * 100
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.opacityUnfocused = 1 - value / 100
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("windows.blur")
                        suffix: ""
                        from: 0
                        to: 12
                        value: page.prefs.blurStrength
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        enabled: page.prefs.surfaceStyle === "glass"
                        opacity: page.prefs.surfaceStyle === "glass" ? 1 : 0.35
                        onMoved: page.prefs.blurStrength = value
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.t("windows.opacityHelp")
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                        wrapMode: Text.WordWrap
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "layout"
                    icon: "view_column"
                    title: page.t("windows.tabLayout")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "view_carousel"
                        label: page.t("layout.scrolling")
                        description: page.t("layout.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.windowLayout === "scrolling"
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) {
                                page.prefs.windowLayout = value ? "scrolling" : "dwindle"
                            }
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("layout.columns")
                        from: 1
                        to: 5
                        stepSize: 1
                        value: page.prefs.visibleColumns
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        enabled: page.prefs.windowLayout === "scrolling"
                        opacity: page.prefs.windowLayout === "scrolling" ? 1 : 0.35
                        onMoved: page.prefs.visibleColumns = value
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.t("layout.perColumn") + " "
                              + Math.round(page.screenWidth / page.prefs.visibleColumns) + " px"
                        color: page.palette.muted
                        font.pixelSize: 12
                        font.family: VitrailTokens.fontFamily
                    }

                    VitrailSettingRow {
                        enabled: page.prefs.windowLayout === "scrolling"
                        icon: "center_focus_strong"
                        label: page.t("layout.followFocus")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.followFocus
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.followFocus = value }
                        }
                    }

                    VitrailSettingRow {
                        enabled: page.prefs.windowLayout === "scrolling"
                        icon: "repeat"
                        label: page.t("layout.wrapFocus")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.wrapFocus
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.wrapFocus = value }
                        }
                    }
                }
            }
        }
    }
}
