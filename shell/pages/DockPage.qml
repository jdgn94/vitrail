import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../../bar/dock"
import "../../bar/dock/dock.js" as Dock

// Dock category: the per-monitor dock's own settings. The bar reads dock.ini;
// the in-place editor offers the same controls, plus a preview of its screen.
// The pinned list is one JSON document (order included), written whole.
Item {
    id: page

    property var palette
    property var prefs
    property var strings

    readonly property var pinned: Dock.parsePinned(page.prefs.dockPinned || "[]")
    readonly property string magnifyStyle: Dock.magnifyStyle(page.prefs.dockMagnify)
    readonly property int magnifyRange: page.prefs.dockMagnifyRange !== undefined
                                        ? Math.max(1, Math.min(5, Number(page.prefs.dockMagnifyRange)))
                                        : VitrailTokens.dock.magnify.range
    readonly property real magnifyScale: page.prefs.dockMagnifyScale !== undefined
                                         ? Math.max(1.1, Math.min(2, Number(page.prefs.dockMagnifyScale)))
                                         : VitrailTokens.dock.magnify.scale

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function options(keys, prefix) {
        var out = []
        for (var i = 0; i < keys.length; i++)
            out.push({ key: keys[i], label: page.t(prefix + keys[i]) })
        return out
    }

    function edgeOptions() {
        return page.options(["bottom", "top", "left", "right"], "dock.edge.")
    }

    function magnifyOptions() {
        return page.options(["none", "planet", "individual"], "dock.magnify.")
    }

    function store(list) {
        page.prefs.dockPinned = Dock.serializePinned(list)
    }

    function removePin(entry) {
        page.store(Dock.togglePin(page.pinned, entry))
    }

    function movePin(index, delta) {
        page.store(Dock.move(page.pinned, index, index + delta))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: VitrailTokens.gap("lg")

        Flickable {
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
                    icon: "dock"
                    title: page.t("section.dock")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSettingRow {
                        icon: "dock"
                        label: page.t("dock.enabled")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "dockPageEnabled"

                            checked: page.prefs.dockEnabled === true
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: page.prefs.dockEnabled = value
                        }
                    }

                    VitrailSettingRow {
                        icon: "vertical_align_bottom"
                        label: page.t("dock.edge")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            objectName: "dockPageEdge"

                            options: page.edgeOptions()
                            current: page.prefs.dockEdge || "bottom"
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.dockEdge = key
                        }
                    }

                    VitrailSettingRow {
                        icon: "visibility_off"
                        label: page.t("dock.autohide")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSwitch {
                            objectName: "dockPageAutohide"

                            checked: page.prefs.dockAutohide === true
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onToggled: page.prefs.dockAutohide = value
                        }
                    }

                    VitrailSettingRow {
                        icon: "space_dashboard"
                        label: page.t("dock.attach")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            objectName: "dockPageAttached"

                            options: [{ key: "attached", label: page.t("dock.attached") },
                                      { key: "floating", label: page.t("dock.floating") }]
                            current: page.prefs.dockAttached !== false ? "attached" : "floating"
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.dockAttached = key === "attached"
                        }
                    }

                    VitrailSettingRow {
                        icon: "open_in_full"
                        label: page.t("dock.magnify")
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSegmented {
                            objectName: "dockPageMagnify"

                            options: page.magnifyOptions()
                            current: page.magnifyStyle
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.dockMagnify = key
                        }
                    }

                    VitrailSettingRow {
                        objectName: "dockPageMagnifyRangeRow"

                        icon: "straighten"
                        label: page.t("dock.magnifyRange")
                        visible: page.magnifyStyle === "planet"
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSlider {
                            Layout.preferredWidth: 240
                            from: VitrailTokens.ranges.dockMagnifyRange.min
                            to: VitrailTokens.ranges.dockMagnifyRange.max
                            stepSize: VitrailTokens.ranges.dockMagnifyRange.step
                            value: page.magnifyRange
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onMoved: page.prefs.dockMagnifyRange = value
                        }
                    }

                    VitrailSettingRow {
                        objectName: "dockPageMagnifyScaleRow"

                        icon: "photo_size_select_large"
                        label: page.t("dock.magnifyScale")
                        visible: page.magnifyStyle !== "none"
                        foreground: page.palette.foreground
                        muted: page.palette.muted

                        VitrailSlider {
                            Layout.preferredWidth: 240
                            from: VitrailTokens.ranges.dockMagnifyScale.min * 100
                            to: VitrailTokens.ranges.dockMagnifyScale.max * 100
                            stepSize: VitrailTokens.ranges.dockMagnifyScale.step * 100
                            value: page.magnifyScale * 100
                            suffix: "%"
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onMoved: page.prefs.dockMagnifyScale = value / 100
                        }
                    }

                    DockMagnifyPreview {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: VitrailTokens.gap("xs")
                        visible: page.magnifyStyle !== "none"
                        style: page.magnifyStyle
                        range: page.magnifyRange
                        factor: page.magnifyScale
                    }
                }

                Section {
                    Layout.fillWidth: true
                    icon: "keep"
                    title: page.t("dock.pinned")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailText {
                        Layout.fillWidth: true
                        visible: page.pinned.length === 0
                        variant: "label"
                        color: page.palette.muted
                        text: page.t("dock.pinned.empty")
                    }

                    Repeater {
                        model: page.pinned

                        delegate: RowLayout {
                            id: pinnedRow

                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("xs")

                            VitrailIcon {
                                icon: "apps"
                                size: "sm"
                            }

                            VitrailText {
                                Layout.fillWidth: true
                                variant: "body"
                                elide: Text.ElideRight
                                text: pinnedRow.modelData.name
                            }

                            VitrailButton {
                                variant: "plain"
                                size: "sm"
                                icon: "arrow_upward"
                                enabled: pinnedRow.index > 0
                                onClicked: page.movePin(pinnedRow.index, -1)
                            }

                            VitrailButton {
                                variant: "plain"
                                size: "sm"
                                icon: "arrow_downward"
                                enabled: pinnedRow.index < page.pinned.length - 1
                                onClicked: page.movePin(pinnedRow.index, 1)
                            }

                            VitrailButton {
                                variant: "text"
                                tone: "error"
                                size: "sm"
                                icon: "delete"
                                onClicked: page.removePin(pinnedRow.modelData)
                            }
                        }
                    }
                }

                Section {
                    Layout.fillWidth: true
                    icon: "widgets"
                    title: page.t("dock.widgets")
                    foreground: page.palette.foreground
                    accent: page.palette.primary

                    VitrailSurface {
                        Layout.fillWidth: true
                        implicitHeight: notice.implicitHeight + 2 * VitrailTokens.gap("md")
                        radius: VitrailTokens.radius * 0.85
                        tint: page.palette.surfaceHigh
                        opacityLevel: page.prefs.surfaceOpacity

                        Column {
                            id: notice

                            anchors.centerIn: parent
                            spacing: VitrailTokens.gap("xs")

                            VitrailIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                icon: "widgets"
                                size: "lg"
                                tone: "muted"
                            }

                            VitrailText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                variant: "label"
                                color: page.palette.muted
                                text: page.t("dock.widgetsNotice")
                            }
                        }
                    }
                }
            }
        }
    }
}
