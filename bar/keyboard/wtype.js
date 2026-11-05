// What a key press sends through `wtype`. The kit keyboard emits `typed` for a
// character and `key` for an xkb key name; only the bar turns those into
// processes. Tested in tests/qml/tst_keyboard.qml.
.pragma library

function typed(text) {
    return ["wtype", String(text)]
}

function key(name) {
    return ["wtype", "-k", String(name)]
}
