// How the panel groups notifications by app: pure rules, tested in
// tests/qml/tst_notification_groups.qml.
.pragma library

// The tallest a group's body grows before it scrolls. This is the design spec
// (no token fits it): about three cards, so one busy app cannot push the
// others out of the panel.
var BODY_MAX = 400

// The tallest a notification's picture grows inside the panel (design spec):
// a screenshot stays a preview and cannot push the other notifications away.
var PICTURE_MAX = 240

// How square a notification image must be to count as an avatar: the longer
// side over the shorter one (design spec). Chat and contact avatars are
// square, attachments and screenshots usually are not.
var AVATAR_ASPECT = 1.25

// The group a notification belongs to.
function groupKey(row) {
    return row.appName || row.icon || "?"
}

// Splits `rows` (plain objects with appName, icon, arrived; the queue's history
// order) into groups { key, appName, icon, rows }. Rows run newest first inside
// a group and groups by their newest row, both falling back to the history
// order when two arrived in the same millisecond.
function groupRows(rows, unknownLabel) {
    var order = {}
    var byKey = {}
    var groups = []
    for (var i = 0; i < rows.length; i++) {
        var row = rows[i]
        var key = groupKey(row)
        order[row.nid] = i
        if (!byKey[key]) {
            byKey[key] = {
                key: key,
                appName: row.appName || unknownLabel,
                icon: row.icon || "",
                rows: []
            }
            groups.push(byKey[key])
        }
        byKey[key].rows.push(row)
    }
    var newest = function (a, b) {
        return b.arrived - a.arrived || order[a.nid] - order[b.nid]
    }
    for (var g = 0; g < groups.length; g++)
        groups[g].rows.sort(newest)
    // `sort` is stable, so groups with the same newest row keep first appearance.
    groups.sort(function (a, b) {
        return b.rows[0].arrived - a.rows[0].arrived
    })
    return groups
}

function bodyHeight(contentHeight, cap) {
    return Math.min(contentHeight, cap)
}

function scrolls(contentHeight, cap) {
    return contentHeight > cap
}

// Where a notification's image is shown, in exactly one place:
//   "none"    there is no image;
//   "avatar"  the circle on the left (the app icon is not shown then). Also the
//             answer while the size is unknown (not loaded yet), so the image
//             does not jump out of the circle for an avatar that is still
//             loading;
//   "picture" a large preview under the text, and the circle falls back to the
//             app icon.
// An image whose longer side is at most AVATAR_ASPECT times the shorter one is
// an avatar; exactly AVATAR_ASPECT still is.
function imageSlot(image, width, height) {
    if (!image)
        return "none"
    if (!(width > 0) || !(height > 0))
        return "avatar"
    var aspect = Math.max(width, height) / Math.min(width, height)
    return aspect <= AVATAR_ASPECT ? "avatar" : "picture"
}

// The height of a picture shown `width` wide: its aspect kept, at most `cap`.
function pictureHeight(width, imageWidth, imageHeight, cap) {
    if (!(imageWidth > 0) || !(imageHeight > 0))
        return 0
    return Math.min(width * imageHeight / imageWidth, cap)
}
