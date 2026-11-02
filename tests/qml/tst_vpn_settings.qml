import QtQuick
import QtTest
import "../../shell/vpnsettings.js" as Doc

// The one VPN document Vitrail keeps (misc.ini `vpnSettings`): which
// connections the automatic choice may use.
TestCase {
    name: "VpnSettings"

    function test_a_missing_or_broken_text_is_an_empty_document() {
        compare(Doc.parse("").connections, {})
        compare(Doc.parse("not json").connections, {})
        compare(Doc.parse("[1]").connections, {})
        compare(Doc.parse('{"connections": [1]}').connections, {})
        compare(Doc.parse("null").connections, {})
    }

    function test_the_old_document_is_dropped_down_to_what_still_means_something() {
        var old = JSON.stringify({
            users: [{ id: "juan", name: "Juan" }], active: "juan", extra: [{ name: "x" }], options: { dns: "1.1.1.1" },
            assignments: [{ vpn: "us-1", users: ["juan"], mode: "full", hosts: [] }]
        })
        compare(Doc.parse(old), { connections: {} })
        var mixed = JSON.stringify({ users: [], connections: { "us-1": { auto: false }, "us-2": { auto: true },
                                                                  "us-3": {}, "us-4": 5, "us-5": null } })
        compare(Doc.parse(mixed), { connections: { "us-1": { auto: false } } })
    }

    function test_a_connection_is_in_the_automatic_choice_unless_it_says_otherwise() {
        var doc = Doc.parse(JSON.stringify({ connections: { "us-1": { auto: false } } }))
        compare(Doc.isAuto(doc, "us-1"), false)
        compare(Doc.isAuto(doc, "us-2"), true)
    }

    function test_leaving_one_out_and_putting_it_back() {
        var doc = Doc.parse("")
        compare(Doc.setAuto(doc, "us-1", true), null)
        var out = Doc.setAuto(doc, "us-1", false)
        compare(out.connections, { "us-1": { auto: false } })
        compare(doc.connections, {})
        compare(Doc.setAuto(out, "us-1", false), null)
        compare(Doc.setAuto(out, "us-1", true).connections, {})
    }

    function test_the_text_round_trips_and_python_reads_the_same_shape() {
        var out = Doc.setAuto(Doc.parse(""), "us-1", false)
        compare(Doc.stringify(out), '{"connections":{"us-1":{"auto":false}}}')
        compare(Doc.parse(Doc.stringify(out)), out)
    }

    function test_connections_that_are_gone_are_forgotten() {
        var doc = Doc.parse(JSON.stringify({ connections: { a: { auto: false }, b: { auto: false } } }))
        compare(Doc.prune(doc, ["a", "c"]).connections, { a: { auto: false } })
        compare(Doc.prune(doc, ["a", "b"]), null)
    }
}
