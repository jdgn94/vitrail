import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
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
        return page.options(["none", "scale", "lift"], "dock.magnify.")
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
                            current: page.prefs.dockMagnify || "scale"
                            foreground: page.palette.foreground
                            accent: page.palette.primary
                            onSelected: page.prefs.dockMagnify = key
                        }
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
