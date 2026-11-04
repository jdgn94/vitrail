// What the bar reads from the system's tools for its connection chip. Tested
// in tests/qml/tst_connection.qml.
.pragma library

// `powerprofilesctl get` prints the profile; balanced when unknown.
function powerProfile(text) {
    var value = String(text || "").trim()
    return value !== "" ? value : "balanced"
}
