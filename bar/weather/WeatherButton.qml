import QtQuick
import ".."
import "../dashboard/dashboard.js" as Dash
import "weather.js" as Weather

// The weather bar element: the condition glyph and the current temperature
// with its unit, from vitrail.weather's snapshot (BarSnapshot). "Only while
// active" means the snapshot carries a temperature: an offline start with no
// cache hides the button instead of leaving an empty slot. A warm cache keeps
// drawing the last reading while the service reports its error in the popup.
BarElementBase {
    id: root

    // The element's data: vitrail.weather's snapshot.
    property var snapshot: ({})

    readonly property bool ready: Weather.ready(root.snapshot)
    readonly property var current: Weather.current(root.snapshot)
    readonly property var unit: Weather.units(root.snapshot)
    readonly property var highLow: Weather.highLow(root.snapshot)
    readonly property string city: root.snapshot && root.snapshot.location
                                    && root.snapshot.location.name !== undefined
                                    ? String(root.snapshot.location.name) : ""
    readonly property string condition: Weather.condition(root.strings, root.current.code,
                                                          root.current.condition)

    icon: Weather.iconOf(root.current.code)
    text: root.ready ? Dash.temperature(root.current.temperature, root.unit.temperature) : ""
    active: root.ready
    tooltip: !root.ready ? root.t("bar.widget.weather")
             : root.city !== "" ? root.t("bar.weather.tooltip").replace("%1", root.city)
                                                       .replace("%2", root.condition)
             : root.condition
    tooltipDetail: !root.ready ? root.t("bar.weather.unavailable")
                   : root.t("bar.weather.highLow")
                         .replace("%1", Dash.degrees(root.highLow.high))
                         .replace("%2", Dash.degrees(root.highLow.low))
}
