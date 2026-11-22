import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/clipboardbar"
import "../../bar/clipboardbar/clipboardbar.js" as ClipboardBar

// The clipboard bar element: the five-copy cut, the redaction the history
// shares, the button's live tooltip, the compact rich previews and the two
// actions (copy an entry, open the full history).
TestCase {
    id: testCase

    name: "ClipboardBar"
    when: windowShown
    visible: true
    width: 440
    height: 980

    readonly property var strings: ({
        "bar.widget.clipboardbar": "Clipboard",
        "bar.clipboardbar.none": "No copies",
        "bar.clipboardbar.empty": "Nothing copied yet.",
        "bar.clipboardbar.tooltip.one": "1 copy · %1",
        "bar.clipboardbar.tooltip": "%1 copies · %2",
        "bar.clipboardbar.open": "Open history",
        "bar.clipboardbar.hint": "A click copies the entry again.",
        "bar.clipboardbar.recentOption": "Copies shown",
        "bar.clipboardbar.recentOption.help": "How many the popup lists (1–10)."
    })

    function t(key) {
        return strings[key] === undefined ? key : strings[key]
    }

    function entry(id, preview) {
        return { id: id, preview: preview }
    }

    function many(count) {
        var list = []
        for (var i = 1; i <= count; i++)
            list.push(entry(String(i), "copy " + i))
        return list
    }

    Component {
        id: buttonComponent

        ClipboardBarButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        ClipboardBarPanel {
            width: 380
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    // createTemporaryObject's property map round-trips through QVariant, which
    // turns a short array into something Array.isArray rejects; the shell
    // assigns plain JS values by binding, so the tests assign them too.
    function build(component, props) {
        var item = createTemporaryObject(component, testCase)
        for (var key in props)
            item[key] = props[key]
        return item
    }

    function find(item, name) {
        var out = []
        function walk(node) {
            if (node.objectName === name)
                out.push(node)
            var kids = node.children || []
            for (var i = 0; i < kids.length; i++)
                walk(kids[i])
        }
        walk(item)
        return out
    }

    // --- the rules -----------------------------------------------------------

    function test_the_cut_takes_the_newest_five_unique_copies() {
        var rows = ClipboardBar.recent(many(8), 5)
        compare(rows.length, 5)
        compare(rows[0].preview, "copy 1")
        compare(rows[4].preview, "copy 5")
        compare(ClipboardBar.count(many(8)), 8)

        var repeated = [entry("3", "same"), entry("2", "other"), entry("1", "same")]
        compare(ClipboardBar.recent(repeated, 5).length, 2)
        compare(ClipboardBar.count(repeated), 2)
    }

    function test_a_colour_is_not_a_copy() {
        var rows = [
            entry("4", "#AABBCC"),
            entry("3", "rgb(1, 2, 3)"),
            entry("2", "copied text"),
            entry("1", "[[ binary data 12 KiB png 80x60 ]]")
        ]
        compare(ClipboardBar.count(rows), 2)
        compare(ClipboardBar.recent(rows, 5).length, 2)
        compare(ClipboardBar.newest(rows), "copied text")
        compare(ClipboardBar.newest([entry("9", "#123456")]), "")
    }

    function test_no_secret_reaches_the_label() {
        compare(ClipboardBar.label(entry("1", "hola\n  dos")), "hola dos")
        verify(ClipboardBar.label(entry("1", "password=hunter2")).indexOf("hunter2") < 0)
        verify(ClipboardBar.label(entry("1", "api_key: sk-live-123")).indexOf("sk-live-123") < 0)
        verify(ClipboardBar.label(entry("1", "Authorization: Bearer abc.def")).indexOf("abc.def") < 0)
        var url = ClipboardBar.label(entry("1", "https://user:pw@example.com/x"))
        verify(url.indexOf("example.com") >= 0)
        verify(url.indexOf("pw") < 0)
        verify(ClipboardBar.label(entry("1", "-----BEGIN RSA PRIVATE KEY-----\nMIIE\n-----END RSA PRIVATE KEY-----"))
               .indexOf("MIIE") < 0)
        compare(ClipboardBar.label(entry("1", "[[ binary data 12 KiB png 80x60 ]]")), "PNG · 80×60")
    }

    function test_the_newest_and_the_oldest_are_redacted_labels() {
        var rows = [entry("3", "password=one"), entry("2", "segunda"), entry("1", "tercera")]
        verify(ClipboardBar.newest(rows).indexOf("one") < 0)
        compare(ClipboardBar.oldest(rows, 2), "segunda")
        compare(ClipboardBar.oldest(rows, 5), "tercera")
        compare(ClipboardBar.oldest([], 5), "")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_reports_the_copies_and_the_newest_one() {
        var button = build(buttonComponent, { entries: many(3), limit: 5 })
        verify(button.active)
        verify(button.shown)
        compare(button.icon, "content_paste")
        compare(button.tooltip, "3 copies · copy 1")
        compare(button.tooltipDetail, "copy 3")

        var one = build(buttonComponent, { entries: [entry("1", "primera")], limit: 5 })
        compare(one.tooltip, "1 copy · primera")
        compare(one.tooltipDetail, "primera")
    }

    function test_the_button_is_inactive_with_no_copies_and_says_so() {
        var button = build(buttonComponent, { entries: [], limit: 5 })
        verify(!button.active)
        compare(button.tooltip, "No copies")
        compare(button.tooltipDetail, "Nothing copied yet.")
    }

    function test_the_tooltip_never_shows_a_secret() {
        var button = build(buttonComponent, { entries: [entry("1", "password=hunter2")], limit: 5 })
        verify(button.tooltip.indexOf("hunter2") < 0)
        verify(button.tooltipDetail.indexOf("hunter2") < 0)
    }

    // --- the popup -----------------------------------------------------------

    function test_the_popup_draws_the_cut_and_the_empty_state() {
        var panel = build(panelComponent, { entries: many(8), limit: 5 })
        compare(find(panel, "clipboardRow").length, 5)
        verify(!find(panel, "empty")[0].visible)

        var empty = build(panelComponent, { entries: [], limit: 5 })
        compare(find(empty, "clipboardRow").length, 0)
        verify(find(empty, "empty")[0].visible)
    }

    function test_the_preview_pane_is_rich_and_compact() {
        var panel = build(panelComponent, {
            entries: [entry("1", "texto"), entry("2", "[[ binary data 12 KiB png 80x60 ]]")],
            limit: 5,
            previews: ({ "1": { kind: "text", text: "texto", html: "<b>texto</b>" } }),
            thumbs: ({ "2": "/tmp/vitrail-clip-2.png" })
        })
        var cards = find(panel, "clipboardPreview")
        compare(cards.length, 2)
        verify(cards[0].compact)
        verify(cards[1].isImage)
        compare(cards[1].image, "/tmp/vitrail-clip-2.png")
    }

    function test_a_click_copies_and_the_button_opens_the_history() {
        var panel = build(panelComponent, { entries: many(3), limit: 5 })
        waitForRendering(panel)
        var copied = []
        var histories = []
        panel.copyRequested.connect(function (id) { copied.push(id) })
        panel.historyRequested.connect(function () { histories.push(true) })
        var row = find(panel, "clipboardRow")[0]
        verify(row.height > 0)
        mouseClick(row, row.width / 2, row.height / 2)
        compare(copied, ["1"])
        find(panel, "openHistory")[0].clicked()
        compare(histories.length, 1)
    }

    function test_the_popup_asks_for_the_history_and_the_previews() {
        var panel = build(panelComponent, {
            entries: [entry("1", "texto"), entry("2", "[[ binary data 12 KiB png 80x60 ]]")],
            limit: 5
        })
        var previews = []
        var thumbs = []
        var refreshes = 0
        panel.previewRequested.connect(function (id) { previews.push(id) })
        panel.thumbRequested.connect(function (id) { thumbs.push(id) })
        panel.refreshRequested.connect(function () { refreshes++ })
        panel.loadPreviews()
        panel.refresh()
        compare(previews, ["1"])
        compare(thumbs, ["2"])
        compare(refreshes, 1)
    }

    function test_the_gear_opens_the_element_settings() {
        var panel = build(panelComponent, { entries: [], limit: 5 })
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        find(panel, "popupSettings")[0].clicked()
        compare(asked, 1)
    }
}
