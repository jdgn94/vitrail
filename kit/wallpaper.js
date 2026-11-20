// Which animation the incoming wallpaper gets.
//
// The choice is a hash of the picture's path, not a coin flipped at random:
// two outputs showing the same picture start the same animation together, and
// a picture keeps its signature when it comes back. `random` picks between the
// two effects; a video changes without one (there is no frame to work with).
.pragma library

var MODES = ["random", "none", "fade", "ink", "outline"]
var VIDEO = /\.(mp4|webm|mkv|mov|m4v|avi)$/i
var DEFAULT_TIME = 1600

// FNV-1a, 32 bits: small, stable across Qt versions, enough to seed a look.
function hash(text) {
    var value = 2166136261
    var source = String(text || "")
    for (var index = 0; index < source.length; index++) {
        value ^= source.charCodeAt(index)
        value = Math.imul(value, 16777619) >>> 0
    }
    return value >>> 0
}

function mode(raw) {
    return MODES.indexOf(raw) >= 0 ? raw : "random"
}

// The kind, duration (ms), noise seed and the point the ink grows from.
function spec(source, preference, time) {
    var chosen = mode(preference)
    if (chosen === "none" || !source || VIDEO.test(String(source)))
        return { kind: "none", duration: 0, seed: 0, originX: 0.5, originY: 0.5 }

    var seed = hash(source)
    var base = Number(time)
    if (!isFinite(base) || base <= 0)
        base = DEFAULT_TIME

    return {
        kind: chosen === "random" ? ((seed & 1) === 0 ? "ink" : "outline") : chosen,
        // A little longer or shorter each picture, never off the setting by
        // more than a sixth.
        duration: Math.round(base * (0.85 + ((seed >>> 8) % 31) / 100)),
        seed: ((seed >>> 13) % 1000) / 1000,
        originX: 0.15 + ((seed >>> 20) % 71) / 100,
        originY: 0.15 + ((seed >>> 24) % 71) / 100
    }
}

// Whether the wallpaper stands still: the Settings switch and a fullscreen
// window on the screen. A preference that was never written reads as on.
function hold(preference, fullscreen) {
    return preference !== false && fullscreen === true
}
