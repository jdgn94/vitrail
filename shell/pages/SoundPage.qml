import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"

// Sound category: the apps of the volume and microphone cards. The devices
// themselves are chosen in those cards; this page only says what the lists do.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    property string tab: "output"

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
                { key: "output", icon: "speaker", label: page.t("sound.tab.output") },
                { key: "input", icon: "mic", label: page.t("sound.tab.input") }
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
                    visible: page.tab === "output"
                    icon: "speaker"
                    title: page.t("sound.section.output")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "apps"
                        label: page.t("sound.outputApps")
                        description: page.t("sound.outputApps.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.soundOutputApps
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.soundOutputApps = value }
                        }
                    }

                    VitrailSettingRow {
                        icon: "center_focus_strong"
                        label: page.t("sound.focusApps")
                        description: page.t("sound.focusApps.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.soundFocusApps
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.soundFocusApps = value }
                        }
                    }

                    VitrailSlider {
                        Layout.fillWidth: true
                        label: page.t("sound.step")
                        suffix: "%"
                        from: VitrailTokens.ranges.soundStep.min
                        to: VitrailTokens.ranges.soundStep.max
                        stepSize: VitrailTokens.ranges.soundStep.step
                        value: page.prefs.soundStep
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onMoved: page.prefs.soundStep = value
                    }
                }

                Section {
                    Layout.fillWidth: true
                    visible: page.tab === "input"
                    icon: "mic"
                    title: page.t("sound.section.input")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "apps"
                        label: page.t("sound.inputApps")
                        description: page.t("sound.inputApps.help")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            checked: page.prefs.soundInputApps
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: function (value) { page.prefs.soundInputApps = value }
                        }
                    }
                }
            }
        }
    }
}
