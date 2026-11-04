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
}
