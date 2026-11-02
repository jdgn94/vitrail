import QtQuick
import QtTest
import "../../bar/network/vpn.js" as Vpn

// How a hypraether-vpn connection reads in the bar.
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

    function test_a_connection_is_offered_to_the_users_it_is_assigned_to() {
        var other = { id: "c", name: "c.conf", active: false }
        var list = [idle, other, proton]
        var settings = JSON.stringify({ active: "ana", assignments: [
            { vpn: "b", users: ["juan"] }, { vpn: "c", users: ["juan", "ana"] }, { vpn: "us-free-26-protonvpn-udp", users: ["juan"] }] })
        // Not assigned to Ana: hidden, unless it is the tunnel that is up.
        compare(Vpn.available(list, settings), [other, proton])
        compare(Vpn.available(list, JSON.stringify({ active: "juan", assignments: [{ vpn: "b", users: ["juan"] }] })), list)
    }

    function test_an_unassigned_connection_or_no_active_user_shows_everything() {
        var list = [idle, proton]
        compare(Vpn.available(list, JSON.stringify({ active: "ana", assignments: [{ vpn: "b", users: [] }] })), list)
        compare(Vpn.available(list, JSON.stringify({ active: "", assignments: [{ vpn: "b", users: ["juan"] }] })), list)
        compare(Vpn.available(list, ""), list)
        compare(Vpn.available(list, "not json"), list)
    }
}
