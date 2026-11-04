import QtQuick
import QtTest
import "../../shell/pages"

// A page is built when its category is first shown, and kept afterwards.
TestCase {
    id: testCase

    name: "LazyPage"
    when: windowShown
    visible: true
    width: 200
    height: 200

    Item {
        id: host

        anchors.fill: parent

        LazyPage {
            id: lazy

            Item {
                property string typed: ""
            }
        }
    }

    Component {
        id: tabbed

        LazyPage {
            Item {
                property string tab: "first"
            }
        }
    }

    function test_built_on_first_show_and_kept() {
        compare(lazy.item, null)
        lazy.shown = true
        verify(lazy.item !== null)
        lazy.item.typed = "kept"
        lazy.shown = false
        compare(lazy.visible, false)
        compare(lazy.item.typed, "kept")
        lazy.shown = true
        compare(lazy.item.typed, "kept")
    }

    function test_a_jump_tab_is_waiting_when_the_page_is_built() {
        var fresh = createTemporaryObject(tabbed, host)
        fresh.jumpTab = "cursor"
        fresh.shown = true
        compare(fresh.item.tab, "cursor")
    }

    function test_a_new_jump_tab_overrides_a_manual_tab() {
        var fresh = createTemporaryObject(tabbed, host)
        fresh.shown = true
        compare(fresh.item.tab, "first")
        fresh.item.tab = "manual"
        fresh.jumpTab = "cursor"
        compare(fresh.item.tab, "cursor")
        fresh.jumpTab = ""
        fresh.item.tab = "manual"
        compare(fresh.item.tab, "manual")
    }
}
