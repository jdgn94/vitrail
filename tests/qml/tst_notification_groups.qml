import QtQuick
import QtTest
import "../../bar/notifications/groups.js" as Groups

// How the panel orders its app groups and sizes their body.
TestCase {
    name: "NotificationGroups"

    function row(nid, appName, arrived, icon) {
        return { nid: nid, appName: appName, icon: icon || "", arrived: arrived }
    }

    function nids(group) {
        return group.rows.map(function (r) { return r.nid })
    }

    function keys(groups) {
        return groups.map(function (g) { return g.key })
    }

    function test_the_key_is_the_app_name_then_the_icon_then_a_mark() {
        compare(Groups.groupKey({ appName: "Discord", icon: "chat" }), "Discord")
        compare(Groups.groupKey({ appName: "", icon: "chat" }), "chat")
        compare(Groups.groupKey({ appName: "", icon: "" }), "?")
    }

    function test_a_burst_of_twenty_stays_grouped() {
        var rows = []
        var apps = ["Telegram", "Discord", "Vitrail", "Correo"]
        for (var i = 0; i < 20; i++)
            rows.push(row(i + 1, apps[i % apps.length], 100 + i))
        var groups = Groups.groupRows(rows, "Unknown")
        compare(groups.length, 4)
        for (var g = 0; g < groups.length; g++) {
            compare(groups[g].rows.length, 5)
            var ids = nids(groups[g])
            var sorted = ids.slice().sort(function (a, b) { return b - a })
            compare(ids, sorted)
        }
        // The app that received the last one comes first.
        compare(groups[0].key, "Correo")
    }

    function test_rows_inside_a_group_run_newest_first() {
        var groups = Groups.groupRows([row(1, "A", 100), row(3, "A", 300), row(2, "A", 200)], "Unknown")
        compare(groups.length, 1)
        compare(nids(groups[0]), [3, 2, 1])
    }

    function test_equal_arrivals_keep_the_history_order() {
        var groups = Groups.groupRows([row(5, "A", 100), row(4, "A", 100), row(6, "A", 100)], "Unknown")
        compare(nids(groups[0]), [5, 4, 6])
    }

    function test_groups_run_by_their_newest_arrival() {
        var groups = Groups.groupRows([row(1, "A", 100), row(2, "B", 300), row(3, "C", 200)], "Unknown")
        compare(keys(groups), ["B", "C", "A"])
    }

    function test_equal_newest_arrivals_keep_first_appearance() {
        var groups = Groups.groupRows([row(1, "A", 100), row(2, "B", 100)], "Unknown")
        compare(keys(groups), ["A", "B"])
    }

    function test_a_new_arrival_in_an_older_group_moves_it_to_the_top() {
        var rows = [row(2, "B", 200), row(1, "A", 100)]
        compare(keys(Groups.groupRows(rows, "Unknown")), ["B", "A"])
        rows.unshift(row(3, "A", 300))
        var groups = Groups.groupRows(rows, "Unknown")
        compare(keys(groups), ["A", "B"])
        compare(nids(groups[0]), [3, 1])
    }

    function test_removing_the_newest_row_reorders_the_groups() {
        var rows = [row(3, "A", 300), row(2, "B", 200), row(1, "A", 100)]
        compare(keys(Groups.groupRows(rows, "Unknown")), ["A", "B"])
        rows.shift()
        compare(keys(Groups.groupRows(rows, "Unknown")), ["B", "A"])
    }

    function test_a_group_carries_its_label_and_icon() {
        var groups = Groups.groupRows([row(1, "Mail", 100, "mail"), row(2, "", 90, "chat"), row(3, "", 80, "")], "Unknown")
        compare(groups[0].appName, "Mail")
        compare(groups[0].icon, "mail")
        compare(groups[1].key, "chat")
        compare(groups[1].appName, "Unknown")
        compare(groups[2].key, "?")
    }

    function test_nothing_gives_no_groups() {
        compare(Groups.groupRows([], "Unknown"), [])
    }

    function test_the_body_follows_its_content_up_to_the_cap() {
        compare(Groups.bodyHeight(120, Groups.BODY_MAX), 120)
        compare(Groups.bodyHeight(0, Groups.BODY_MAX), 0)
    }

    function test_the_cap_is_four_hundred() {
        compare(Groups.BODY_MAX, 400)
        compare(Groups.bodyHeight(400, Groups.BODY_MAX), 400)
        compare(Groups.bodyHeight(900, Groups.BODY_MAX), 400)
    }

    function test_the_body_scrolls_only_past_the_cap() {
        verify(!Groups.scrolls(399, Groups.BODY_MAX))
        verify(!Groups.scrolls(400, Groups.BODY_MAX))
        verify(Groups.scrolls(401, Groups.BODY_MAX))
    }

    function test_no_image_has_no_slot() {
        compare(Groups.imageSlot("", 100, 100), "none")
        compare(Groups.imageSlot("", 0, 0), "none")
        compare(Groups.imageSlot(undefined, 100, 100), "none")
    }

    function test_an_image_of_unknown_size_is_an_avatar_until_it_loads() {
        compare(Groups.imageSlot("file:///a.png", 0, 0), "avatar")
        compare(Groups.imageSlot("file:///a.png", 300, 0), "avatar")
        compare(Groups.imageSlot("file:///a.png", 0, 300), "avatar")
        compare(Groups.imageSlot("file:///a.png", -1, -1), "avatar")
    }

    function test_square_and_nearly_square_images_are_avatars() {
        compare(Groups.imageSlot("file:///a.png", 128, 128), "avatar")
        compare(Groups.imageSlot("file:///a.png", 120, 100), "avatar")
        compare(Groups.imageSlot("file:///a.png", 100, 120), "avatar")
    }

    function test_wide_and_tall_images_are_pictures() {
        compare(Groups.imageSlot("file:///a.png", 1920, 1080), "picture")
        compare(Groups.imageSlot("file:///a.png", 400, 800), "picture")
    }

    function test_the_aspect_boundary_is_still_an_avatar() {
        compare(Groups.AVATAR_ASPECT, 1.25)
        compare(Groups.imageSlot("file:///a.png", 125, 100), "avatar")
        compare(Groups.imageSlot("file:///a.png", 100, 125), "avatar")
        compare(Groups.imageSlot("file:///a.png", 126, 100), "picture")
        compare(Groups.imageSlot("file:///a.png", 100, 126), "picture")
    }

    function test_a_picture_keeps_its_aspect_up_to_the_cap() {
        compare(Groups.PICTURE_MAX, 240)
        compare(Groups.pictureHeight(300, 1600, 800, Groups.PICTURE_MAX), 150)
        compare(Groups.pictureHeight(300, 400, 800, Groups.PICTURE_MAX), 240)
        compare(Groups.pictureHeight(300, 0, 0, Groups.PICTURE_MAX), 0)
    }

    function test_two_conversations_of_one_app_are_two_groups() {
        var groups = Groups.groupRows([
            { nid: 1, appName: "Telegram", conversation: "Ana", arrived: 100 },
            { nid: 2, appName: "Telegram", conversation: "Luis", arrived: 200 },
            { nid: 3, appName: "Telegram", conversation: "Ana", arrived: 300 }
        ], "Unknown")
        compare(groups.length, 2)
        compare(groups[0].conversation, "Ana")
        compare(groups[0].rows.length, 2)
        compare(groups[1].conversation, "Luis")
        compare(groups[1].rows.length, 1)
        compare(groups[0].key, "Telegram\u0000Ana")
    }
}
