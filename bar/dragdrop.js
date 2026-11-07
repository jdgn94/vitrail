.pragma library
.import "layouts.js" as Layouts

// The drag surface of the bar editor: where a dragged row may land and the
// document that dropping it there produces. It is pure: the editor measures
// the pointer, asks for a raw target ({ group, index } or { chip, index }) and
// gets back a checked target or the document the drop would write. Nothing
// here reads a preference or touches a file.
//
// The sources are the rows of the bar tab: an order entry (an element, a
// divider or a whole chip, `"@connections"`) or one member of a chip. A target
// is a gap in a group's order or a gap in a chip's members.
//
// The rules are layouts.js' rules, not new ones: a fixed element keeps its
// group, a divider is never a chip member, an element joins one chip at most,
// and a chip never becomes a member of a chip (itself included).

// Where an entry lives: { id, kind, group, index, chip }. A chip member has no
// place in the order (index -1) and names its chip.
function source(doc, id) {
    var order = doc && doc.order ? doc.order : {}
    var name = ""
    for (var group in order) {
        var at = order[group].indexOf(id)
        if (at >= 0) {
            name = group
            return {
                id: id,
                kind: Layouts.isChipToken(id) ? "chip"
                      : (Layouts.isDivider(id) ? "divider" : "element"),
                group: group,
                index: at,
                chip: Layouts.isChipToken(id) ? Layouts.chipName(id) : ""
            }
        }
    }
    var chip = doc && doc.chips ? Layouts.chipOf(doc.chips, id) : null
    if (chip !== null) {
        var place = Layouts.chipPlace(order, chip)
        return { id: id, kind: "member", group: place ? place.group : "",
                 index: -1, chip: chip }
    }
    return null
}

function whole(value) {
    var number = Number(value)
    return isFinite(number) ? Math.round(number) : null
}

function clamp(value, minimum, maximum) {
    return Math.max(minimum, Math.min(maximum, value))
}

// This row's gap: the top half inserts before it, the bottom half after it.
function insertion(base, y, height) {
    var index = whole(base)
    if (index === null)
        index = 0
    var size = Number(height)
    if (!isFinite(size) || size <= 0)
        return index + 1
    return Number(y) < size / 2 ? index : index + 1
}

// A raw target checked against the document: { valid, kind, group|chip, index,
// id } or { valid: false, reason }. `reason` names the rule that refused it:
// "source", "group", "chip", "self", "fixed" or "structural".
function target(doc, id, raw) {
    var origin = source(doc, id)
    if (!origin)
        return { valid: false, reason: "source" }
    if (!raw || typeof raw !== "object")
        return { valid: false, reason: "target" }

    if (raw.kind === "chip") {
        var chipId = typeof raw.chip === "string" ? raw.chip : ""
        if (!Layouts.chipEntry(doc.chips, chipId))
            return { valid: false, reason: "chip" }
        // A chip is placed by its token, never inside another chip; the chip
        // being dragged onto its own body is the clearest version of that.
        if (origin.kind === "chip")
            return { valid: false, reason: origin.chip === chipId ? "self" : "structural" }
        if (Layouts.isFixed(id, "bar"))
            return { valid: false, reason: "fixed" }
        if (!Layouts.chipMember(id, "bar"))
            return { valid: false, reason: "structural" }
        var members = Layouts.chipEntry(doc.chips, chipId).members
        var memberIndex = raw.index === undefined ? members.length : whole(raw.index)
        if (memberIndex === null)
            memberIndex = members.length
        return { valid: true, kind: "chip", id: id, chip: chipId,
                 group: origin.group, index: clamp(memberIndex, 0, members.length) }
    }

    if (raw.kind === "group") {
        var group = typeof raw.group === "string" ? raw.group : ""
        if (Layouts.groups("bar").indexOf(group) < 0)
            return { valid: false, reason: "group" }
        if (origin.kind !== "member" && Layouts.isFixed(id, "bar")
            && group !== Layouts.homeGroup(id, "bar"))
            return { valid: false, reason: "fixed" }
        var list = doc.order && doc.order[group] ? doc.order[group] : []
        var place = raw.index === undefined ? list.length : whole(raw.index)
        if (place === null)
            place = list.length
        return { valid: true, kind: "group", id: id, chip: "", group: group,
                 index: clamp(place, 0, list.length) }
    }

    return { valid: false, reason: "target" }
}

// The new order and chips for dropping `id` on `raw`, or null when the target
// is refused (or would change nothing). The input document is never changed.
function apply(doc, id, raw) {
    var place = target(doc, id, raw)
    if (!place.valid)
        return null
    var origin = source(doc, id)
    if (!origin)
        return null

    if (place.kind === "chip") {
        var members = Layouts.chipEntry(doc.chips, place.chip).members.slice()
        var from = members.indexOf(id)
        if (from < 0) {
            members.splice(clamp(place.index, 0, members.length), 0, id)
            return Layouts.setChipMembers(doc.order, doc.chips, place.chip, members, "bar")
        }
        // Already a member: the gap is a place in this same list, so the
        // removal below moves every later index back by one.
        var at = clamp(place.index, 0, members.length)
        members.splice(from, 1)
        if (from < at)
            at -= 1
        members.splice(clamp(at, 0, members.length), 0, id)
        return Layouts.setChipMembers(doc.order, doc.chips, place.chip, members, "bar")
    }

    if (origin.kind === "member") {
        // The member first returns to the order beside its chip, then moves to
        // the gap the pointer marked. Removing it shifts the entries after the
        // chip by one; the requested index follows the pointer, so it follows
        // that shift too.
        var rest = Layouts.chipEntry(doc.chips, origin.chip).members.filter(function (member) {
            return member !== id
        })
        var stepped = Layouts.setChipMembers(doc.order, doc.chips, origin.chip, rest, "bar")
        var after = Layouts.chipPlace(stepped.order, origin.chip)
        var index = place.index
        if (after && after.group === place.group && place.index > after.index)
            index += 1
        return { order: Layouts.moveTo(stepped.order, id, place.group, index, "bar"),
                 chips: stepped.chips }
    }

    return { order: Layouts.moveTo(doc.order, id, place.group, place.index, "bar"),
             chips: doc.chips }
}

// The document the bar would show with the drop applied, for the preview
// strip; null when the target is refused. The input is never changed.
function preview(doc, id, raw) {
    var result = apply(doc, id, raw)
    if (result === null)
        return null
    return {
        order: result.order,
        chips: result.chips,
        hidden: (doc.hidden || []).slice(),
        density: doc.density,
        hideFullscreen: doc.hideFullscreen
    }
}
