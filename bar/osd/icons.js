// The Material Symbol each OSD slider shows, from its state. Every name here
// is checked by tests/test_icons.py.
.pragma library

// volume: 0..1, muted: boolean.
function volume(volume, muted) {
    if (muted)
        return "volume_off"
    if (volume <= 0)
        return "volume_mute"
    return volume < 0.5 ? "volume_down" : "volume_up"
}

function mic(muted) {
    return muted ? "mic_off" : "mic"
}

// level: 0..1.
function brightness(level) {
    if (level < 1 / 3)
        return "brightness_low"
    return level < 2 / 3 ? "brightness_medium" : "brightness_high"
}
