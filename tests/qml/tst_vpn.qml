import QtQuick
import QtTest
import "../../bar/network/vpn.js" as Vpn

// How a vitrail-vpn connection reads in the bar.
TestCase {
    name: "Vpn"

    readonly property var proton: ({ id: "us-free-26-protonvpn-udp", name: "us-free-26.protonvpn.udp.ovpn",
                                     provider: "proton", region: "US", active: true })
    readonly property var idle: ({ id: "b", name: "b.conf", provider: "mullvad", region: "", active: false })

    function test_title_drops_the_file_extension_and_the_suffixes() {
        compare(Vpn.title("us-free-12.protonvpn.udp.ovpn"), "us-free-12")
        compare(Vpn.title("office.conf"), "office")
    }

    function test_detail_lists_the_suffixes_and_the_region() {
        compare(Vpn.detail(proton), "protonvpn · udp · US")
        compare(Vpn.detail(idle), "")
    }

    function test_provider_has_a_display_name() {
        compare(Vpn.provider(proton), "ProtonVPN")
        compare(Vpn.provider(idle), "Mullvad")
        compare(Vpn.provider({ name: "x.conf" }), "")
    }

    function test_service_is_the_name_and_the_region() {
        compare(Vpn.service(proton), "us-free-26 · US")
        compare(Vpn.service(idle), "b")
    }

    function test_active_is_the_connected_one() {
        compare(Vpn.active([idle, proton]), proton)
        compare(Vpn.active([idle]), null)
        compare(Vpn.active([]), null)
    }

    function test_quality_levels() {
        compare(Vpn.level({ latency: 74, loss: 0 }), "good")
        compare(Vpn.level({ latency: 99.9, loss: null }), "good")
        compare(Vpn.level({ latency: 100, loss: 0 }), "fair")
        compare(Vpn.level({ latency: 40, loss: 5 }), "fair")
        compare(Vpn.level({ latency: 249, loss: 10 }), "fair")
        compare(Vpn.level({ latency: 250, loss: 0 }), "poor")
        compare(Vpn.level({ latency: 40, loss: 11 }), "poor")
        compare(Vpn.level({ latency: null, loss: 100 }), "unknown")
        compare(Vpn.level({}), "unknown")
        compare(Vpn.level(undefined), "unknown")
    }

    function test_latency_label() {
        compare(Vpn.latency({ latency: 73.6, loss: 0 }), "74 ms")
        compare(Vpn.latency({ latency: null, loss: 100 }), "—")
        compare(Vpn.latency(undefined), "—")
    }

    function test_probe_is_asked_only_for_stale_measurements() {
        compare(Vpn.needsProbe(100000, 0, 0, 60000, 3), true)
        compare(Vpn.needsProbe(100000, 90000, 0, 60000, 3), false)
        compare(Vpn.needsProbe(100000, 0, 95000, 60000, 3), false)
        compare(Vpn.needsProbe(160000, 90000, 0, 60000, 3), true)
        compare(Vpn.needsProbe(100000, 0, 0, 60000, 0), false)
    }
}
