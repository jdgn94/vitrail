import QtQuick
import QtTest
import "../../kit"
import "../../bar/network"

// The settings gear of a popup: one definition in the kit, and the rule that it
// sits at the top right (references/popups.md). The panels that import
// Quickshell cannot load here; tests/test_popup_gear.py checks those.
TestCase {
    id: testCase

    name: "PopupGear"
    when: windowShown
    visible: true
    width: 600
    height: 400

    VitrailPalette {
        id: palette
    }

    Component {
        id: gearControl

        VitrailPopupGear { }
    }

    Component {
        id: powerControl

        PowerProfilePanel {
            width: implicitWidth
            strings: ({
                "connection.power.saver": "Saver",
                "connection.power.balanced": "Balanced",
                "connection.power.performance": "Performance",
                "powerprofile.saver.detail": "Slower clocks and a dimmer screen.",
                "powerprofile.balanced.detail": "Speed when it is needed.",
                "powerprofile.performance.detail": "Full speed: more heat."
            })
            profile: "balanced"
        }
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function test_the_gear_is_the_one_settings_button() {
        var gear = createTemporaryObject(gearControl, testCase)
        verify(gear)
        compare(gear.icon, "settings")
        compare(gear.variant, "plain")
        compare(gear.tone, "secondary")
        compare(gear.size, "sm")
    }

    // The last item of the first row, in the top-right corner.
    function test_the_gear_sits_at_the_top_right() {
        var panel = createTemporaryObject(powerControl, testCase)
        verify(panel)
        wait(50)
        var found = findChild(panel, "popupSettings")
        verify(found !== null)
        var point = found.mapToItem(panel, 0, 0)
        // Right edge: within a gap of the panel's own width.
        verify(point.x + found.width >= panel.width - VitrailTokens.gap("sm"),
               "gear right " + (point.x + found.width) + " panel width " + panel.width)
        // Top: the first row, not below it.
        verify(point.y <= VitrailTokens.gap("md"), "gear top " + point.y)
    }
}
