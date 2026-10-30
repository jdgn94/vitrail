pragma Singleton
import QtQuick

// Variant catalogue: name -> style expressed in token roles, never literals.
QtObject {
    readonly property var text: ({
        display: { size: "display", weight: Font.Light, role: "foreground", opacity: 1.0 },
        title: { size: "title", weight: Font.DemiBold, role: "foreground", opacity: 1.0 },
        subtitle: { size: "subtitle", weight: Font.Medium, role: "foreground", opacity: 0.92 },
        body: { size: "body", weight: Font.Normal, role: "foreground", opacity: 1.0 },
        content: { size: "content", weight: Font.Normal, role: "muted", opacity: 1.0 },
        label: { size: "label", weight: Font.Medium, role: "muted", opacity: 0.9 },
        icon: { size: "title", weight: Font.Normal, role: "foreground", opacity: 1.0, family: "icons" }
    })

    // Button emphasis, from most to least. `fill` / `hover` are the fill
    // alpha at rest and under the pointer, `ink` is "on" (the tone's on-colour,
    // over a solid fill) or "tone" (the tone itself), `shadow` the elevation
    // in px, `inset` sinks the button, `rest` dims the ink until hovered.
    //   elevated  the one call to action that floats above a busy surface
    //   flat      main action of a card, dialog or row
    //   inset     a toggle that is on, a pressed-in choice
    //   tonal     secondary actions next to a flat one
    //   outlined  alternatives and cancels, on calm surfaces
    //   text      low-emphasis actions inside content, menus, links
    //   plain     toolbar and icon actions that must not draw a fill
    readonly property var button: ({
        elevated: { fill: 1.0, hover: 1.0, ink: "on", border: 0, shadow: 3, inset: false, rest: 1.0, motion: "fast" },
        flat: { fill: 1.0, hover: 0.88, ink: "on", border: 0, shadow: 0, inset: false, rest: 1.0, motion: "fast" },
        inset: { fill: 1.0, hover: 0.92, ink: "on", border: 0, shadow: 0, inset: true, rest: 1.0, motion: "fast" },
        tonal: { fill: 0.22, hover: 0.32, ink: "tone", border: 0, shadow: 0, inset: false, rest: 1.0, motion: "fast" },
        outlined: { fill: 0.0, hover: 0.10, ink: "tone", border: 1, shadow: 0, inset: false, rest: 1.0, motion: "fast" },
        text: { fill: 0.0, hover: 0.10, ink: "tone", border: 0, shadow: 0, inset: false, rest: 1.0, motion: "fast" },
        plain: { fill: 0.0, hover: 0.0, ink: "tone", border: 0, shadow: 0, inset: false, rest: 0.7, motion: "fast" }
    })

    // Colour families any button variant can take: fill role and its ink.
    readonly property var tone: ({
        primary: { role: "primary", on: "accentForeground" },
        secondary: { role: "foreground", on: "surface" },
        info: { role: "info", on: "infoForeground" },
        error: { role: "error", on: "errorForeground" }
    })

    readonly property var field: ({
        outline: { role: "surfaceHigh", text: "foreground", alpha: 0.85, border: 1, motion: "fast" },
        filled: { role: "surfaceHigh", text: "foreground", alpha: 1.0, border: 0, motion: "fast" }
    })

    readonly property var surface: ({
        glass: { alpha: 0.62, border: 1, edge: 0.18, blur: true },
        solid: { alpha: 1.0, border: 0, edge: 0.0, blur: false }
    })

    // Screen frame: a border around the whole screen whose inner corners
    // follow the system radius. The bar docks into it.
    readonly property var frame: ({
        full: { border: true, corners: true, role: "surface", motion: "slow" },
        corners: { border: false, corners: true, role: "surface", motion: "slow" },
        none: { border: false, corners: false, role: "surface", motion: "slow" }
    })

    // System bar: docked melts into the frame, floating is an island inside it.
    readonly property var bar: ({
        docked: { docked: true, gap: "sm", motion: "base" },
        floating: { docked: false, gap: "sm", motion: "base" }
    })

    // Side panels: full grows out of the frame along a whole edge; overlay
    // floats above the wallpaper and the windows without moving anything.
    readonly property var panel: ({
        full: { attached: true, gap: "md", motion: "slow" },
        overlay: { attached: false, gap: "md", motion: "slow" }
    })

    // Wallpaper fit: inside the frame hole (follows panels) or the whole
    // screen (never moves).
    readonly property var wallpaper: ({
        frame: { fit: "frame", motion: "slow" },
        screen: { fit: "screen", motion: "slow" }
    })
}
