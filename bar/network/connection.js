// What the connection panel reads from the system's tools. Tested in
// tests/qml/tst_connection.qml.
.pragma library

// The `ADDR / GW / DNS` lines of the details script.
function details(text) {
    var out = { address: "", gateway: "", dns: "" }
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.indexOf("ADDR ") === 0)
            out.address = line.slice(5).trim()
        else if (line.indexOf("GW ") === 0)
            out.gateway = line.slice(3).trim()
        else if (line.indexOf("DNS ") === 0)
            out.dns = line.slice(4).trim()
    }
    return out
}

// `bluetoothctl devices Paired` lines: "Device AA:BB:CC:DD:EE:FF Name".
// `info` (of the connected one) marks it.
function bluetoothDevices(text, info) {
    var seen = ({})
    var out = []
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim()
        if (line.indexOf("Device ") !== 0)
            continue
        var rest = line.slice(7).trim()
        var at = rest.indexOf(" ")
        var mac = at < 0 ? rest : rest.slice(0, at)
        var name = at < 0 ? mac : rest.slice(at + 1).trim()
        if (seen[mac])
            continue
        seen[mac] = true
        out.push({ mac: mac, name: name, connected: false })
    }
    var connected = String(info || "")
    for (var j = 0; j < out.length; j++) {
        var index = connected.indexOf(out[j].mac)
        if (index >= 0 && connected.slice(index).indexOf("Connected: yes") >= 0)
            out[j].connected = true
    }
    return out
}

// `powerprofilesctl get` prints the profile; balanced when unknown.
function powerProfile(text) {
    var value = String(text || "").trim()
    return value !== "" ? value : "balanced"
}
