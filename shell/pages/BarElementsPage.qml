import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"

// Bar elements category: one block per new-style bar element, each with the
// options every element shares (when it shows) and its own. A bar popup's gear
// lands on its element's block through `tab` (the element's id). A new
// element adds its BarElementSection here (docs/bar-elements.md).
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    // The element whose block to bring into view (a gear or a search result).
    property string tab: ""

    function reveal() {
        for (var i = 0; i < column.children.length; i++) {
            var block = column.children[i]
            if (block.elementId !== undefined && block.elementId === page.tab) {
                scroller.contentY = Math.min(block.y, Math.max(0, scroller.contentHeight - scroller.height))
                return
            }
        }
    }

    onTabChanged: Qt.callLater(page.reveal)

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

            BarElementSection {
                Layout.fillWidth: true
                elementId: "sample"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings
            }

            BarElementSection {
                id: volumeSection

                Layout.fillWidth: true
                elementId: "volume"
                palette: page.palette
                prefs: page.prefs
                strings: page.strings

                VitrailSlider {
                    objectName: "volumeStep"

                    Layout.fillWidth: true
                    label: volumeSection.t("bar.volume.step")
                    suffix: "%"
                    from: VitrailTokens.ranges.volumeStep.min
                    to: VitrailTokens.ranges.volumeStep.max
                    stepSize: VitrailTokens.ranges.volumeStep.step
                    value: page.prefs.volumeStep
                    foreground: page.palette.foreground
                    accent: page.palette.primary
                    onMoved: page.prefs.volumeStep = value
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    icon: "text_fields"
                    label: volumeSection.t("bar.volume.percent")
                    description: volumeSection.t("bar.volume.percent.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "volumePercent"
                        checked: page.prefs.volumePercent === true
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.volumePercent = value }
                    }
                }

                VitrailSettingRow {
                    Layout.fillWidth: true
                    icon: "visibility_off"
                    label: volumeSection.t("bar.volume.hideSilent")
                    description: volumeSection.t("bar.volume.hideSilent.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        objectName: "volumeHideSilent"
                        checked: page.prefs.volumeHideSilent === true
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.volumeHideSilent = value }
                    }
                }
            }

            Item { Layout.preferredHeight: VitrailTokens.gap("xl") }
        }
    }
}
