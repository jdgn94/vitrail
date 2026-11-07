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

    // Text field looks. `fill` is the box fill alpha, `hover` the state layer
    // alpha under the pointer, `border` / `focus` the
    // outline (or bottom line) width at rest and when focused or in error,
    // `notch` opens the outline behind the floating label, `indicator` grows
    // the bottom line from the centre on focus.
    //   outline  no fill, the label floats into a notch of the outline
    //   filled   surfaceHigh fill, top corners rounded, label rides inside
    readonly property var field: ({
        outline: { role: "surfaceHigh", text: "foreground", fill: 0.0, hover: 0.06, border: 1, focus: 2, notch: true, indicator: false, motion: "base" },
        filled: { role: "surfaceHigh", text: "foreground", fill: 1.0, hover: 0.08, border: 1, focus: 2, notch: false, indicator: true, motion: "base" }
    })

    // Surface styles, the one source for every container. `alpha` multiplies
    // the user's opacity, `edge` is the light edge, `raised` / `raisedHover`
    // the alpha of a card inside a container (notification cards, rows):
    // glass keeps them translucent, solid makes them opaque.
    readonly property var surface: ({
        glass: { alpha: 0.62, border: 1, edge: 0.18, blur: true, raised: 0.7, raisedHover: 0.9 },
        solid: { alpha: 1.0, border: 0, edge: 0.0, blur: false, raised: 1.0, raisedHover: 1.0 }
    })

    // Screen frame: a border around the whole screen whose inner corners
    // follow the system radius. The bar docks into it.
    readonly property var frame: ({
        full: { border: true, corners: true, role: "surface", motion: "slow" },
        corners: { border: false, corners: true, role: "surface", motion: "slow" },
        none: { border: false, corners: false, role: "surface", motion: "slow" }
    })

    // System bar: docked melts into the frame, floating is an island inside it.
    // The islands variants split the bar by slot group: docked, the frame stays
    // thin and rises into an island under each group; floating, each group is
    // its own pill.
    readonly property var bar: ({
        docked: { docked: true, islands: false, gap: "sm", motion: "base" },
        floating: { docked: false, islands: false, gap: "sm", motion: "base" },
        islands: { docked: true, islands: true, gap: "sm", motion: "base" },
        floatingIslands: { docked: false, islands: true, gap: "sm", motion: "base" }
    })

    // Side panels: full grows out of the frame along a whole edge; overlay
    // floats above the wallpaper and the windows without moving anything.
    readonly property var panel: ({
        full: { attached: true, gap: "md", motion: "slow" },
        overlay: { attached: false, gap: "md", motion: "slow" }
    })

    // The dock: flush against the screen edge (square outer corners, no
    // margin) or floating above it (round corners and a margin).
    readonly property var dock: ({
        attached: { attached: true, radius: 0, margin: 0, motion: "base" },
        floating: { attached: false, radius: 1, margin: "md", motion: "base" }
    })

    // Application launcher: one content component, two presentations. Sizes
    // come from tokens.launcher[`metrics`]; `field` is the search field's size,
    // `gap` the spacing step between blocks, `label` the text variant of an app
    // name and `lines` how many lines it may take, `fill` takes the whole
    // screen instead of a card.
    //   popout      compact card that grows out of the bar button
    //   fullscreen  dimmed screen, centred field, big icon grid
    readonly property var launcher: ({
        popout: { metrics: "popout", field: "md", gap: "md", label: "label", lines: 1, fill: false, motion: "base" },
        fullscreen: { metrics: "fullscreen", field: "lg", gap: "lg", label: "content", lines: 2, fill: true, motion: "slow" }
    })

    // Wallpaper fit: inside the frame hole (follows panels) or the whole
    // screen (never moves).
    readonly property var wallpaper: ({
        frame: { fit: "frame", motion: "slow" },
        screen: { fit: "screen", motion: "slow" }
    })

    // The audio visualiser (kit/composed/VitrailVisualiser). `shape` picks the
    // primitive; `reflection` and `panel` decorate the bars look.
    //   bars        bars from the bottom edge, no container
    //   reflection  bars above a mirror that fades below the baseline
    //   panel       the bars inside a rounded surface, inset from the edges
    //   circle      a radial ring of bars around the centre
    //   waves       smooth wave lines across the strip
    readonly property var visualiser: ({
        bars: { shape: "bars", reflection: false, panel: false, motion: "base" },
        reflection: { shape: "bars", reflection: true, panel: false, motion: "base" },
        panel: { shape: "bars", reflection: false, panel: true, motion: "base" },
        circle: { shape: "circle", reflection: false, panel: false, motion: "base" },
        waves: { shape: "waves", reflection: false, panel: false, motion: "base" }
    })
}
