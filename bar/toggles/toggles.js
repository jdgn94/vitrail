// The quick toggles read their state from the tools' own text, so the panel
// shows what the system says instead of what was clicked. Tested in
// tests/qml/tst_toggles.qml.
.pragma library

// `nmcli radio wifi` prints enabled or disabled.
function wifiOn(text) {
    return String(text || "").trim() === "enabled"
}

// `bluetoothctl show` has "Powered: yes" while an adapter is on.
function bluetoothOn(text) {
    return /Powered:\s*yes/i.test(String(text || ""))
}

// No adapter (no Controller line, no Powered line): the toggle is hidden.
function bluetoothPresent(text) {
    return /(Controller|Powered:)/i.test(String(text || ""))
}

// `wpctl get-volume @DEFAULT_AUDIO_SOURCE@` adds "[MUTED]" when it is muted.
function micMuted(text) {
    return /\[MUTED\]/i.test(String(text || ""))
}
