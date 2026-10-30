import QtQuick
import ".."
import "../frame.js" as Frame

// The timeline of something that opens and closes like a drop of liquid
// (glass) or as a short smooth fade (solid): popups and the notification
// stack. `progress` runs 0..1 while `open` flips; `look` is what the shape
// does at that moment (frame.js liquid / smooth), for tabs and floating cards
// to bind to. Nothing runs while it rests, and `shown` tells when a window
// that hosts it must stay up to finish closing.
QtObject {
    id: root

    property bool open: false
    // Off, progress follows `open` at once (static previews set it by hand).
    property bool animated: true
    property real progress: root.open ? 1 : 0

    readonly property bool shown: root.open || root.progress > 0
    readonly property var tokens: VitrailTokens.glass ? VitrailTokens.motion.liquid : VitrailTokens.motion.smooth
    readonly property var look: VitrailTokens.glass ? Frame.liquid(root.progress, root.tokens)
                                                    : Frame.smooth(root.progress, root.tokens)

    // The timeline is linear: the curves live in frame.js.
    Behavior on progress {
        enabled: root.animated
        NumberAnimation { duration: root.open ? root.tokens.open : root.tokens.close }
    }
}
