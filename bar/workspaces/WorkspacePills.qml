pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../kit"
import "workspaces.js" as Workspaces

// The workspace pills at the start of the bar: one per existing workspace,
// the active one in accent, the occupied ones dotted. The entry already knows
// its app class; `iconProvider` maps that class to a theme icon path (the
// shell owns the DesktopEntries lookup, so this file loads offscreen).
Item {
    id: root

    // The mapped entries (`Workspaces.collect`): { id, label, active,
    // occupied, klass, title }.
    property var workspaces: []
    property bool vertical: false
    property var strings: ({})
    // Maps a window class to a theme icon path, or "" for no icon.
    property var iconProvider: null

    signal clicked(int id)
    signal hovered(var item, bool on)

    readonly property bool shown: root.workspaces.length > 0

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    GridLayout {
        id: layout

        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: VitrailTokens.gap("xs")
        columnSpacing: VitrailTokens.gap("xs")

        Repeater {
            model: root.workspaces

            delegate: WorkspacePill {
                id: pill

                required property var modelData

                objectName: "workspacePill." + modelData.id
                label: modelData.label
                active: modelData.active
                occupied: modelData.occupied
                iconSource: root.iconProvider && modelData.klass !== ""
                            ? root.iconProvider(modelData.klass) : ""
                tooltip: Workspaces.tooltip(modelData, root.strings)
                tooltipDetail: Workspaces.tooltipDetail(modelData, root.strings)
                onClicked: root.clicked(modelData.id)
                onHoveredChanged: root.hovered(pill, pill.hovered)
            }
        }
    }
}
