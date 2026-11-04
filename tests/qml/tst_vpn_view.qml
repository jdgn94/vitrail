import QtQuick
import QtTest
import "../../shell/vpnview.js" as View

// The pure helpers of the VPN tab.
TestCase {
    name: "VpnView"

    function test_a_url_is_reduced_to_its_origin() {
        compare(View.normalizeUrl("https://Example.com/a/b?q=1,2"), "https://example.com")
        compare(View.normalizeUrl("http://example.com:8080/x"), "http://example.com")
        compare(View.normalizeUrl("  www.example.co.uk "), "https://www.example.co.uk")
        var bad = ["", "-x.com", "ftp://example.com", "a b.com", "example", "https://user@example.com", "a..com", "https://127.0.0.1"]
        for (var i = 0; i < bad.length; i++)
            compare(View.normalizeUrl(bad[i]), "", bad[i])
    }

    // The same cases as vitrail.network.registrable (tests/test_network.py).
    function test_the_registrable_domain_follows_the_python_heuristic() {
        compare(View.registrable("www.example.com"), "example.com")
        compare(View.registrable("example.com"), "example.com")
        compare(View.registrable("a.b.example.co.uk"), "example.co.uk")
        compare(View.registrable("www.example.com.br"), "example.com.br")
        compare(View.registrable("www.example.org"), "example.org")
    }

    function test_the_flat_list_is_grouped_by_registrable_domain() {
        var groups = View.groupDomains([
            { domain: "www.openai.com", ips: 2 }, { domain: "claude.ai", ips: 2 }, { domain: "openai.com", ips: 3 },
            { domain: "api.openai.com", ips: 0 }, { domain: "bbc.co.uk", ips: 1 }, { domain: "news.bbc.co.uk", ips: 1 }
        ])
        compare(groups.map(function (group) { return group.root }), ["bbc.co.uk", "claude.ai", "openai.com"])
        compare(groups[2].count, 3)
        compare(groups[2].ips, 5)
        compare(groups[2].domains.map(function (one) { return one.domain }), ["api.openai.com", "openai.com", "www.openai.com"])
        compare(groups[0].domains[1], { domain: "news.bbc.co.uk", ips: 1 })
        compare(View.groupDomains([]), [])
    }

    function test_a_dialog_url_becomes_a_path() {
        compare(View.filePath("file:///home/juan/My%20VPN/x.ovpn"), "/home/juan/My VPN/x.ovpn")
        compare(View.filePath("file://localhost/tmp/a.ovpn"), "/tmp/a.ovpn")
        compare(View.filePath("/tmp/typed path.ovpn"), "/tmp/typed path.ovpn")
        compare(View.filePath("relative/x.ovpn"), "")
        compare(View.filePath("https://example.com/x.ovpn"), "")
        compare(View.filePath("file:///bad%zz"), "")
        compare(View.filePath(""), "")
    }

    function test_file_names_and_extensions() {
        compare(View.baseName("/a/b/c.ovpn"), "c.ovpn")
        verify(View.hasExtension("/a/B.OVPN"))
        verify(View.hasExtension("/a/b.conf"))
        verify(!View.hasExtension("/a/b.txt"))
    }

    function test_a_nonce_is_32_hex_digits_and_not_repeated() {
        var one = View.nonce(), two = View.nonce()
        verify(/^[0-9a-f]{32}$/.test(one))
        verify(one !== two)
    }

    function test_requests_carry_objects_as_json() {
        compare(View.request("vpn-cred-add", { name: "a", user: "b" }), 'vpn-cred-add:{"name":"a","user":"b"}')
    }

    function test_an_import_names_only_what_was_given() {
        compare(View.importRequest("/a/x.ovpn", "", ""), 'vpn-import:{"file":"/a/x.ovpn"}')
        compare(View.importRequest("/a/x.ovpn", " My server ", "spare"),
                'vpn-import:{"file":"/a/x.ovpn","name":"My server","credential":"spare"}')
    }

    function test_a_credential_edit_carries_only_the_changes() {
        var current = { name: "work", username: "me" }
        compare(View.updatePayload(current, "work", "me"), null)
        compare(View.updatePayload(current, " ", " "), null)
        compare(View.updatePayload(current, "job", "me"), { name: "work", rename: "job" })
        compare(View.updatePayload(current, "work", "you"), { name: "work", user: "you" })
        compare(View.updatePayload(current, " job ", " you "), { name: "work", rename: "job", user: "you" })
    }
}
