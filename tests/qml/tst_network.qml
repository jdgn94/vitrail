import QtQuick
import QtTest
import "../../bar/network/network.js" as Network

// The network helpers the bar button and the popup share.
TestCase {
    name: "Network"

    function test_wifi_glyph_follows_the_signal() {
        compare(Network.wifiGlyph(0), "signal_wifi_0_bar")
        compare(Network.wifiGlyph(0.5), "network_wifi_2_bar")
        compare(Network.wifiGlyph(1), "signal_wifi_4_bar")
        compare(Network.wifiGlyph(undefined), "signal_wifi_0_bar")
        compare(Network.wifiGlyph(7), "signal_wifi_4_bar")
    }

    function test_ipv4_is_the_first_address_of_ip_json() {
        var text = '[{"ifname":"eno1","addr_info":[{"family":"inet","local":"192.168.1.20","prefixlen":24}]}]'
        compare(Network.ipv4(text), "192.168.1.20")
    }

    function test_ipv4_is_empty_without_an_address() {
        compare(Network.ipv4("[]"), "")
        compare(Network.ipv4('[{"addr_info":[]}]'), "")
        compare(Network.ipv4("not json"), "")
        compare(Network.ipv4(""), "")
    }
}
