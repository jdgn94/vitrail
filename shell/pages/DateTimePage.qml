import QtQuick
import QtQuick.Layouts
import "../../kit"
import "../../kit/base"
import "../worldmap.js" as Map

// Date & time category: the time zone on a world map, and automatic time.
// The zone is chosen first and applied with a button: applying asks for the
// user's password (polkit, answered by the bar), so a click on the map must
// not. Both settings are written to the settings file; apply-settings.sh
// changes the system.
Item {
    id: page

    property var palette
    property var prefs
    property var strings
    // [{ id, lat, lon, offset, note }] from `vitrail.timezones`, and what the
    // system has now (read once at startup).
    property var zones: []
    property string systemZone: ""
    property bool systemNtp: true
    property string tab: "zone"

    // The zone clicked or searched; before any, the one in the settings or the system's.
    property string picked: ""
    readonly property string chosen: page.picked !== "" ? page.picked : (page.prefs.timezone || page.systemZone)
    readonly property var chosenZone: Map.find(page.zones, page.chosen)
    readonly property var systemEntry: Map.find(page.zones, page.systemZone)
    readonly property var matches: Map.search(page.zones, search.text)
    readonly property bool ntp: page.prefs.ntp === "" ? page.systemNtp : page.prefs.ntp === "true"
    property real now: Date.now()

    onTabChanged: scroller.contentY = 0

    function t(key) {
        var value = page.strings[key]
        return value === undefined ? key : value
    }

    function describe(zone) {
        return zone ? zone.id.replace(/_/g, " ") + " · " + Map.offsetLabel(zone.offset) : page.systemZone
    }

    Timer {
        interval: 30000
        running: page.visible
        repeat: true
        onTriggered: page.now = Date.now()
    }

    VitrailTabs {
        id: tabBar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        tabs: [
            { key: "zone", icon: "public", label: page.t("datetime.zone") },
            { key: "clock", icon: "schedule", label: page.t("datetime.clock") }
        ]
        current: page.tab
        foreground: page.palette.foreground
        accent: page.palette.primary
        onSelected: page.tab = key
    }

    Flickable {
        id: scroller

        anchors.top: tabBar.bottom
        anchors.topMargin: VitrailTokens.gap("lg")
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: column

            width: parent.width
            spacing: VitrailTokens.gap("xl")

            Section {
                Layout.fillWidth: true
                visible: page.tab === "zone"
                icon: "public"
                title: page.t("datetime.zone")
                foreground: page.palette.foreground
                accent: page.palette.primary

                Text {
                    Layout.fillWidth: true
                    text: page.t("datetime.help")
                    color: page.palette.muted
                    font.pixelSize: 12
                    font.family: VitrailTokens.fontFamily
                    wrapMode: Text.WordWrap
                }

                VitrailSettingRow {
                    icon: "schedule"
                    label: page.t("datetime.current")
                    description: page.describe(page.systemEntry)
                    foreground: page.palette.foreground
                    muted: page.palette.muted
                }

                WorldMap {
                    Layout.fillWidth: true
                    zones: page.zones
                    selected: page.chosen
                    current: page.systemZone
                    sea: page.palette.surface
                    land: page.palette.surfaceHigh
                    accent: page.palette.primary
                    foreground: page.palette.foreground
                    onPicked: function (id) { page.picked = id }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: VitrailTokens.gap("sm")

                    VitrailField {
                        id: search

                        Layout.fillWidth: true
                        label: page.t("datetime.search")
                        leadingIcon: "search"
                    }

                    VitrailButton {
                        Layout.alignment: Qt.AlignTop
                        variant: "flat"
                        icon: "check"
                        text: page.t("datetime.apply")
                        enabled: page.chosen !== "" && page.chosen !== page.systemZone
                                 && page.chosen !== page.prefs.timezone
                        onClicked: page.prefs.timezone = page.chosen
                    }
                }

                VitrailSettingRow {
                    visible: page.chosenZone !== null
                    icon: "place"
                    label: page.t("datetime.selected")
                    description: page.chosenZone
                                 ? page.describe(page.chosenZone) + " · " + Map.localTime(page.chosenZone.offset, page.now)
                                 : ""
                    foreground: page.palette.foreground
                    muted: page.palette.muted
                }

                Text {
                    Layout.fillWidth: true
                    visible: page.matches.length === 0
                    text: page.t("datetime.empty")
                    color: page.palette.muted
                    font.pixelSize: 12
                    font.family: VitrailTokens.fontFamily
                }

                ListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(count, 5) * 44
                    visible: count > 0
                    clip: true
                    model: page.matches
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: entry

                        required property var modelData

                        readonly property bool active: entry.modelData.id === page.chosen

                        width: list.width
                        height: 44

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: height / 2
                            color: entry.active ? Qt.rgba(page.palette.primary.r, page.palette.primary.g, page.palette.primary.b, 0.18)
                                                : Qt.rgba(page.palette.foreground.r, page.palette.foreground.g, page.palette.foreground.b, hover.hovered ? 0.06 : 0)
                        }

                        HoverHandler {
                            id: hover
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: VitrailTokens.gap("md")
                            anchors.rightMargin: VitrailTokens.gap("md")
                            spacing: VitrailTokens.gap("sm")

                            Text {
                                text: Map.city(entry.modelData.id)
                                color: entry.active ? page.palette.primary : page.palette.foreground
                                font.pixelSize: 14
                                font.weight: entry.active ? Font.DemiBold : Font.Normal
                                font.family: VitrailTokens.fontFamily
                            }

                            Text {
                                Layout.fillWidth: true
                                text: [Map.region(entry.modelData.id), entry.modelData.note].filter(function (part) { return part !== "" }).join(" · ")
                                color: page.palette.muted
                                elide: Text.ElideRight
                                font.pixelSize: 12
                                font.family: VitrailTokens.fontFamily
                            }

                            Text {
                                text: Map.offsetLabel(entry.modelData.offset)
                                color: page.palette.muted
                                font.pixelSize: 12
                                font.family: VitrailTokens.fontFamily
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.picked = entry.modelData.id
                        }
                    }
                }
            }

            Section {
                Layout.fillWidth: true
                visible: page.tab === "clock"
                icon: "update"
                title: page.t("datetime.clock")
                foreground: page.palette.foreground
                accent: page.palette.primary

                VitrailSettingRow {
                    icon: "sync"
                    label: page.t("datetime.ntp")
                    description: page.t("datetime.ntp.help")
                    foreground: page.palette.foreground
                    muted: page.palette.muted

                    VitrailSwitch {
                        checked: page.ntp
                        foreground: page.palette.foreground
                        accent: page.palette.primary
                        onToggled: function (value) { page.prefs.ntp = value ? "true" : "false" }
                    }
                }
            }
        }
    }
}
