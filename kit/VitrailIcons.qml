pragma Singleton
import QtQuick
import "icons.js" as Icons

// The one resolver for every Material Symbol the shell draws.
//
// A glyph is a ligature name drawn with the icon family, so `resolve` answers
// the name to draw and `style` says how the active style draws it. A name that
// is empty, unknown or misspelt resolves to `question_mark`, which is why no
// `Text` sets an icon name without passing through here.
QtObject {
    // The family and FILL axis of the active style; `VitrailText` binds its
    // icon font to these, so a preference change repaints every glyph at once.
    readonly property var style: ({
        family: VitrailTokens.iconFamily,
        fill: VitrailTokens.iconFill
    })

    // The glyph an unresolvable name draws.
    readonly property string fallback: Icons.fallback

    // The glyph to draw for `name`: the name itself when it is a known icon,
    // `question_mark` when it is empty or not in the table.
    function resolve(name) {
        return Icons.glyph(name)
    }

    // Whether `name` (ignoring surrounding space and case) is a known icon.
    function available(name) {
        return Icons.available(name)
    }
}
