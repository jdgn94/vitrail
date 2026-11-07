import QtQuick
import QtTest
import "../../bar/dragdrop.js" as DragDrop
import "../../bar/layouts.js" as Layouts

// The bar editor's drag surface, without a pointer: where a row may land (a
// group and a gap, or a chip and a gap), which targets the layout rules refuse,
// and the document each valid drop produces. The preview is the same document
// the drop would write; the editor never writes anything before the release.
TestCase {
    name: "BarDrag"

    function baseDocument() {
        return Layouts.sanitize("")
    }

    function documentWithDivider() {
        var doc = baseDocument()
        return { order: Layouts.addDivider(doc.order, "center"), chips: doc.chips,
                 hidden: doc.hidden, density: doc.density, hideFullscreen: doc.hideFullscreen }
    }

    // --- where a row lives ---------------------------------------------------

    function test_the_source_of_every_kind_of_row() {
        var doc = baseDocument()
        var element = DragDrop.source(doc, "workspaces")
        compare(element.kind, "element")
        compare(element.group, "start")
        compare(element.index, 1)

        var chip = DragDrop.source(doc, "@connections")
        compare(chip.kind, "chip")
        compare(chip.chip, "connections")

        var member = DragDrop.source(doc, "network")
        compare(member.kind, "member")
        compare(member.chip, "connections")
        compare(member.index, -1)

        var divider = DragDrop.source(documentWithDivider(), "divider")
        compare(divider.kind, "divider")
        compare(divider.group, "center")

        compare(DragDrop.source(doc, "not-a-widget"), null)
    }

    // --- the target -----------------------------------------------------------

    function test_a_group_target_checks_the_group_and_clamps_the_gap() {
        var doc = baseDocument()
        var at = DragDrop.target(doc, "clock", { kind: "group", group: "start", index: 0 })
        verify(at.valid)
        compare(at.group, "start")
        compare(at.index, 0)

        compare(DragDrop.target(doc, "clock", { kind: "group", group: "start", index: 99 }).index,
                doc.order.start.length)
        compare(DragDrop.target(doc, "clock", { kind: "group", group: "start", index: -4 }).index, 0)
        compare(DragDrop.target(doc, "clock", { kind: "group", group: "middle", index: 0 }).reason,
                "group")
    }

    function test_a_fixed_element_may_only_move_inside_its_own_group() {
        var doc = baseDocument()
        compare(DragDrop.target(doc, "launcher",
                                { kind: "group", group: "end", index: 0 }).reason, "fixed")
        verify(DragDrop.target(doc, "launcher",
                               { kind: "group", group: "start", index: 2 }).valid)
    }

    function test_a_chip_target_refuses_structural_rows_and_itself() {
        var doc = baseDocument()
        verify(DragDrop.target(doc, "clock",
                               { kind: "chip", chip: "connections", index: 1 }).valid)

        compare(DragDrop.target(documentWithDivider(), "divider",
                                { kind: "chip", chip: "connections", index: 0 }).reason,
                "structural")
        compare(DragDrop.target(doc, "@connections",
                                { kind: "chip", chip: "connections", index: 0 }).reason, "self")
        var made = Layouts.newChip(doc.order, doc.chips, "start", "bar")
        var withChip = { order: made.order, chips: made.chips, hidden: doc.hidden }
        compare(DragDrop.target(withChip, "@connections",
                                { kind: "chip", chip: made.id, index: 0 }).reason,
                "structural")
        // A member may reorder inside its own chip; it may not be dropped on
        // top of itself in a way that changes nothing.
        verify(DragDrop.target(doc, "network",
                               { kind: "chip", chip: "connections", index: 2 }).valid)
        compare(DragDrop.target(doc, "launcher",
                                { kind: "chip", chip: "connections", index: 0 }).reason, "fixed")
        compare(DragDrop.target(doc, "clock",
                                { kind: "chip", chip: "missing", index: 0 }).reason, "chip")
    }

    function test_the_gap_is_the_half_of_the_row_under_the_pointer() {
        compare(DragDrop.insertion(2, 5, 40), 2)
        compare(DragDrop.insertion(2, 30, 40), 3)
        compare(DragDrop.insertion(4, 0, 0), 5)
    }

    // --- the document a drop writes ------------------------------------------

    function test_an_element_moves_between_groups_at_the_gap() {
        var doc = baseDocument()
        var result = DragDrop.apply(doc, "clock", { kind: "group", group: "start", index: 0 })
        compare(result.order.start[0], "clock")
        compare(result.order.center.indexOf("clock"), -1)
        compare(result.order.start.length, doc.order.start.length + 1)
    }

    function test_a_member_leaves_its_chip_at_the_marked_gap() {
        var doc = baseDocument()
        var result = DragDrop.apply(doc, "network", { kind: "group", group: "start", index: 1 })
        compare(result.order.start[1], "network")
        compare(result.chips.connections.members.indexOf("network"), -1)
        // The gap is the pointer's: the member lands before "workspaces", not
        // just beside the chip it left.
        compare(result.order.start.indexOf("network") < result.order.start.indexOf("workspaces"), true)
    }

    function test_a_member_leaves_a_chip_later_in_the_same_group() {
        var doc = baseDocument()
        var result = DragDrop.apply(doc, "network", { kind: "group", group: "end", index: 5 })
        var end = result.order.end
        compare(end[end.indexOf("network") + 1], "keyboard")
        compare(end[end.indexOf("network") - 1], "battery")
        compare(result.chips.connections.members.indexOf("network"), -1)
    }

    function test_a_member_reorders_inside_its_chip() {
        var doc = baseDocument()
        var result = DragDrop.apply(doc, "network",
                                    { kind: "chip", chip: "connections", index: 3 })
        compare(result.chips.connections.members,
                ["bluetooth", "vpn", "network", "profile"])

        var back = DragDrop.apply(doc, "profile",
                                  { kind: "chip", chip: "connections", index: 0 })
        compare(back.chips.connections.members,
                ["profile", "network", "bluetooth", "vpn"])
        compare(back.order.end.indexOf("@connections") >= 0, true)
    }

    function test_a_member_joins_another_chip() {
        var doc = baseDocument()
        var made = Layouts.newChip(doc.order, doc.chips, "start", "bar")
        var withChip = { order: made.order, chips: made.chips, hidden: doc.hidden }
        var result = DragDrop.apply(withChip, "network",
                                    { kind: "chip", chip: made.id, index: 0 })
        compare(result.chips[made.id].members, ["network"])
        compare(result.chips.connections.members.indexOf("network"), -1)
    }

    function test_an_element_joins_a_chip_and_leaves_its_group() {
        var doc = baseDocument()
        var result = DragDrop.apply(doc, "clock",
                                    { kind: "chip", chip: "connections", index: 2 })
        compare(result.chips.connections.members[2], "clock")
        compare(result.order.center.indexOf("clock"), -1)
        verify(result.order.end.indexOf("@connections") >= 0)
    }

    function test_a_chip_moves_as_one_entry_and_a_divider_between_groups() {
        var doc = baseDocument()
        var moved = DragDrop.apply(doc, "@connections",
                                   { kind: "group", group: "center", index: 1 })
        compare(moved.order.center[1], "@connections")
        compare(moved.order.end.indexOf("@connections"), -1)
        compare(moved.chips.connections.members.length, 4)

        var withDivider = documentWithDivider()
        var result = DragDrop.apply(withDivider, "divider",
                                    { kind: "group", group: "start", index: 0 })
        compare(result.order.start[0], "divider")
        compare(result.order.center.indexOf("divider"), -1)
    }

    function test_an_invalid_drop_writes_nothing() {
        var doc = baseDocument()
        compare(DragDrop.apply(doc, "launcher",
                               { kind: "group", group: "end", index: 0 }), null)
        compare(DragDrop.apply(doc, "@connections",
                               { kind: "chip", chip: "connections", index: 0 }), null)
        compare(DragDrop.apply(doc, "not-a-widget",
                               { kind: "group", group: "start", index: 0 }), null)
    }

    // --- the preview ----------------------------------------------------------

    function test_the_preview_is_the_document_the_drop_writes() {
        var doc = baseDocument()
        var before = JSON.stringify(doc)
        var preview = DragDrop.preview(doc, "clock", { kind: "group", group: "start", index: 0 })
        verify(preview !== null)
        compare(preview.order.start[0], "clock")
        compare(preview.hidden, doc.hidden)
        compare(JSON.stringify(doc), before)

        var written = DragDrop.apply(doc, "clock", { kind: "group", group: "start", index: 0 })
        compare(JSON.stringify(preview.order), JSON.stringify(written.order))
        compare(JSON.stringify(preview.chips), JSON.stringify(written.chips))
    }

    function test_the_preview_of_a_refused_target_is_null() {
        var doc = documentWithDivider()
        compare(DragDrop.preview(doc, "divider",
                                 { kind: "chip", chip: "connections", index: 0 }), null)
        compare(DragDrop.preview(doc, "not-a-widget",
                                 { kind: "group", group: "start", index: 0 }), null)
    }
}
