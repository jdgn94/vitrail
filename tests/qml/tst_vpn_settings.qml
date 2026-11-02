import QtQuick
import QtTest
import "../../shell/vpnsettings.js" as Doc

// The VPN document the Connection page keeps in misc.ini (vpnSettings).
TestCase {
    name: "VpnSettings"

    function test_a_missing_or_broken_text_is_an_empty_document() {
        compare(Doc.parse("").users, [])
        compare(Doc.parse("not json").assignments, [])
        compare(Doc.parse("[1]").extra, [])
        compare(Doc.parse("").active, "")
    }

    function test_unknown_parts_survive_a_round_trip() {
        var text = JSON.stringify({ users: [], options: { killSwitch: true, dns: "1.1.1.1" }, future: 3 })
        var doc = Doc.parse(text)
        compare(doc.options.killSwitch, true)
        compare(JSON.parse(Doc.stringify(doc)).future, 3)
    }

    function test_the_first_user_becomes_the_active_one_and_ids_are_unique() {
        var doc = Doc.addUser(Doc.parse(""), " Juan ")
        compare(doc.users[0], { id: "juan", name: "Juan", note: "" })
        compare(doc.active, "juan")
        doc = Doc.addUser(doc, "juan")
        compare(doc.users[1].id, "juan-2")
        compare(doc.active, "juan")
        compare(Doc.addUser(doc, "  "), null)
    }

    function test_renaming_keeps_the_id_and_removing_cleans_every_reference() {
        var doc = Doc.addUser(Doc.addUser(Doc.parse(""), "Juan"), "Ana")
        doc = Doc.toggleUser(Doc.toggleUser(doc, "us-1", "juan"), "us-1", "ana")
        doc = Doc.renameUser(doc, "ana", "Ana M")
        compare(doc.users[1], { id: "ana", name: "Ana M", note: "" })
        compare(Doc.renameUser(doc, "ana", ""), null)
        doc = Doc.removeUser(doc, "juan")
        compare(doc.users.length, 1)
        compare(doc.active, "ana")
        compare(doc.assignments[0].users, ["ana"])
        compare(Doc.removeUser(doc, "ana").active, "")
    }

    function test_choosing_the_active_user_needs_a_known_user() {
        var doc = Doc.addUser(Doc.addUser(Doc.parse(""), "Juan"), "Ana")
        compare(Doc.setActive(doc, "ana").active, "ana")
        compare(Doc.setActive(doc, "nobody").active, "juan")
    }

    function test_an_assignment_is_made_on_first_use_with_split_mode() {
        var doc = Doc.toggleUser(Doc.parse(""), "us-1", "juan")
        compare(doc.assignments, [{ vpn: "us-1", users: ["juan"], mode: "split", hosts: [] }])
        doc = Doc.toggleUser(doc, "us-1", "juan")
        compare(doc.assignments[0].users, [])
        compare(Doc.setMode(doc, "us-1", "full").assignments[0].mode, "full")
        compare(Doc.setMode(doc, "us-1", "weird").assignments[0].mode, "split")
        compare(Doc.assignmentOf(Doc.parse(""), "x").mode, "split")
    }

    function test_a_url_is_reduced_to_its_origin() {
        compare(Doc.normalizeUrl("https://Example.com/a/b?q=1,2"), "https://example.com")
        compare(Doc.normalizeUrl("http://example.com:8080/x"), "http://example.com")
        compare(Doc.normalizeUrl("  www.example.co.uk "), "https://www.example.co.uk")
        var bad = ["", "-x.com", "ftp://example.com", "a b.com", "example", "https://user@example.com", "a..com", "https://127.0.0.1"]
        for (var i = 0; i < bad.length; i++)
            compare(Doc.normalizeUrl(bad[i]), "", bad[i])
    }

    function test_a_host_waits_for_its_answer_and_is_not_added_twice() {
        var doc = Doc.addHost(Doc.parse(""), "us-1", "https://example.com")
        compare(doc.assignments[0].hosts, [{ url: "https://example.com", ips: [], domains: [], pending: true }])
        compare(Doc.pending(doc), true)
        compare(Doc.addHost(doc, "us-1", "https://example.com"), null)
    }

    function test_an_answer_fills_the_waiting_host() {
        var doc = Doc.addHost(Doc.parse(""), "us-1", "https://example.com")
        var next = Doc.merge(doc, { "https://example.com": { ips: ["1.2.3.4"], domains: ["example.com", "www.example.com"] } })
        compare(next.assignments[0].hosts[0], { url: "https://example.com", ips: ["1.2.3.4"],
                                                domains: ["example.com", "www.example.com"], pending: false, retry: false })
        compare(Doc.pending(next), false)
        compare(Doc.merge(next, { "https://example.com": { ips: ["9.9.9.9"], domains: [] } }), null)
        compare(Doc.merge(doc, { "https://other.com": { ips: [], domains: [] } }), null)
    }

    function test_an_offline_answer_marks_a_retry_and_keeps_what_was_there() {
        var doc = Doc.addHost(Doc.parse(""), "us-1", "https://example.com")
        var next = Doc.merge(doc, { "https://example.com": { ips: [], domains: [], retry: true } })
        compare(next.assignments[0].hosts[0].retry, true)
        compare(next.assignments[0].hosts[0].pending, false)
        var again = Doc.markPending(next, "us-1", "https://example.com")
        compare(again.assignments[0].hosts[0].pending, true)
        compare(again.assignments[0].hosts[0].retry, false)
        var filled = Doc.merge(again, { "https://example.com": { ips: ["1.2.3.4"], domains: ["example.com"] } })
        var kept = Doc.merge(Doc.markPending(filled, "us-1", "https://example.com"),
                             { "https://example.com": { ips: [], domains: [], retry: true } })
        compare(kept.assignments[0].hosts[0].ips, ["1.2.3.4"])
    }

    function test_a_host_a_domain_and_an_address_can_each_be_removed() {
        var doc = Doc.addHost(Doc.parse(""), "us-1", "https://example.com")
        doc = Doc.merge(doc, { "https://example.com": { ips: ["1.2.3.4", "5.6.7.8"], domains: ["example.com", "www.example.com"] } })
        doc = Doc.removeDomain(doc, "us-1", "https://example.com", "www.example.com")
        doc = Doc.removeIp(doc, "us-1", "https://example.com", "1.2.3.4")
        compare(doc.assignments[0].hosts[0].domains, ["example.com"])
        compare(doc.assignments[0].hosts[0].ips, ["5.6.7.8"])
        compare(Doc.removeHost(doc, "us-1", "https://example.com").assignments[0].hosts, [])
    }

    function test_extra_connections_are_added_checked_and_removed() {
        var doc = Doc.addExtra(Doc.parse(""), " Office ", "wireguard", " ~/office.conf ")
        compare(doc.extra, [{ name: "Office", type: "wireguard", path: "~/office.conf" }])
        compare(Doc.addExtra(doc, "", "openvpn", "/x"), null)
        compare(Doc.addExtra(doc, "A", "openvpn", ""), null)
        compare(Doc.addExtra(doc, "A", "pptp", "/x").extra[1].type, "other")
        compare(Doc.removeExtra(doc, 0).extra, [])
    }
}
