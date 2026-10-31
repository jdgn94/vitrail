.pragma library

// Signal bars, from empty to full.
function wifiGlyph(strength) {
    var glyphs = ["signal_wifi_0_bar", "network_wifi_1_bar", "network_wifi_2_bar", "network_wifi_3_bar", "signal_wifi_4_bar"]
    return glyphs[Math.max(0, Math.min(4, Math.round((strength || 0) * 4)))]
}

// The first IPv4 address in `ip -j -4 addr show dev <iface>`, or "".
function ipv4(text) {
    try {
        var devices = JSON.parse(text)
        for (var i = 0; i < devices.length; i++) {
            var addresses = devices[i].addr_info || []
            for (var j = 0; j < addresses.length; j++) {
                if (addresses[j].local)
                    return addresses[j].local
            }
        }
    } catch (error) {
    }
    return ""
}
