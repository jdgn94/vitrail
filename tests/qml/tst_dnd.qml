import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/dnd"
import "../../bar/dnd/dnd.js" as Dnd

// The Do Not Disturb element: the state and remaining time of a timed silence,
// the duration buttons, the allowed applications and the clicks it hands to the
// shell.
TestCase {
    id: testCase

    name: "Dnd"
    when: windowShown
    visible: true
    width: 460
    height: 760

    readonly property var strings: ({
        "bar.widget.dnd": "Do not disturb",
        "bar.dnd.off": "Do not disturb is off",
        "bar.dnd.on": "Do not disturb until you turn it off",
        "bar.dnd.remaining": "Do not disturb · %1 left",
        "bar.dnd.bypassOff": "The urgent bypass is off",
        "bar.dnd.noApps": "No application bypasses it",
        "bar.dnd.allowed": "May still come through: %1",
        "bar.dnd.duration": "Duration",
        "bar.dnd.30m": "30 minutes",
        "bar.dnd.1h": "1 hour",
        "bar.dnd.tomorrow": "Until tomorrow",
        "bar.dnd.apps": "Allowed applications",
        "bar.dnd.apps.help": "Their notifications still arrive while Do Not Disturb is on.",
        "bar.dnd.apps.empty": "No application is allowed through",
        "bar.dnd.app.add": "Application name",
        "bar.dnd.bypass": "Urgent notifications bypass it",
        "bar.dnd.bypass.help": "An urgent notification from a listed application is still shown.",
        "bar.duration.minutes": "%1 min",
        "bar.duration.hours": "%1 h",
        "bar.duration.hoursMinutes": "%1 h %2 min",
        "action.add": "Add"
    })

    function t(key) {
        return strings[key] === undefined ? key : strings[key]
    }

    Component {
        id: buttonComponent

        DndButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        DndPanel {
            width: 380
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: toggles; signalName: "toggleRequested" }
    SignalSpy { id: menus; signalName: "menuRequested" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

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

    // --- the plain logic -----------------------------------------------------

    function test_the_durations_are_the_three_the_plan_names() {
        compare(Dnd.DURATIONS, [30, 60, 0])
        compare(Dnd.minutesOf(undefined), 60)
        compare(Dnd.minutesOf(30), 30)
        compare(Dnd.minutesOf(60), 60)
        compare(Dnd.minutesOf(0), 0)
        compare(Dnd.minutesOf(15), 60)
        compare(Dnd.minutesOf("45"), 60)
    }

    function test_a_timed_silence_ends_when_its_time_is_up() {
        var now = 1763730000000
        var state = Dnd.state(true, String(now + 30 * 60000), now)
        compare(state.on, true)
        compare(state.minutes, 30)
        compare(state.timed, true)
        compare(Dnd.state(true, String(now + 30000), now).minutes, 1)
        compare(Dnd.state(true, String(now), now).on, false)
        compare(Dnd.state(true, String(now - 1), now).on, false)
        compare(Dnd.state(false, String(now + 60000), now).on, false)
        compare(Dnd.state(true, "0", now).on, true)
        compare(Dnd.state(true, "0", now).timed, false)
    }

    function test_until_tomorrow_is_eight_in_the_morning() {
        var now = new Date(2026, 10, 22, 23, 0, 0, 0).getTime()
        var until = Dnd.untilFor(0, now)
        var at = new Date(until)
        compare(at.getHours(), 8)
        compare(at.getMinutes(), 0)
        compare(at.getDate(), 23)
        compare(Dnd.untilFor(60, now), now + 60 * 60000)
    }

    function test_the_tooltip_names_the_state_and_the_time_left() {
        var now = 1763730000000
        compare(Dnd.summary(false, "0", now, t), "Do not disturb is off")
        compare(Dnd.summary(true, String(now + 30 * 60000), now, t), "Do not disturb · 30 min left")
        compare(Dnd.summary(true, String(now + 90 * 60000), now, t), "Do not disturb · 1 h 30 min left")
        compare(Dnd.summary(true, "0", now, t), "Do not disturb until you turn it off")
        compare(Dnd.detail("", true, t), "No application bypasses it")
        compare(Dnd.detail("Discord,Spotify", true, t), "May still come through: Discord, Spotify")
        compare(Dnd.detail("Discord", false, t), "The urgent bypass is off")
    }

    function test_the_app_list_round_trips_without_duplicates() {
        compare(Dnd.appList(" Discord, Spotify ,, Discord "), ["Discord", "Spotify"])
        compare(Dnd.withApp("Discord", "Spotify"), "Discord,Spotify")
        compare(Dnd.withApp("Discord", "Discord"), "Discord")
        compare(Dnd.withoutApp("Discord,Spotify", "Discord"), "Spotify")
        compare(Dnd.withoutApp("Discord", "Missing"), "Discord")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_fills_while_dnd_is_on() {
        var now = 1763730000000
        var button = build(buttonComponent, {
            dndOn: true,
            muteUntil: now + 30 * 60000,
            apps: "Discord,Spotify",
            bypass: true,
            now: now
        })
        verify(button.active)
        verify(button.shown)
        compare(button.icon, "bedtime")
        compare(button.tone, "primary")
        compare(button.tooltip, "Do not disturb · 30 min left")
        compare(button.tooltipDetail, "May still come through: Discord, Spotify")

        button.dndOn = false
        verify(!button.active)
        compare(button.icon, "dark_mode")
        compare(button.tone, "secondary")
        compare(button.tooltip, "Do not disturb is off")
    }

    function test_an_expired_silence_reads_as_off_before_the_timer_clears_it() {
        var now = 1763730000000
        var button = build(buttonComponent, { dndOn: true, muteUntil: now - 1, now: now })
        verify(!button.active)
        compare(button.tooltip, "Do not disturb is off")
    }

    function test_left_and_middle_click_toggle_and_right_click_opens_the_menu() {
        var button = build(buttonComponent, {})
        toggles.target = button
        menus.target = button
        toggles.clear()
        menus.clear()
        mouseClick(button, 20, 20, Qt.LeftButton)
        compare(toggles.count, 1)
        mouseClick(button, 20, 20, Qt.MiddleButton)
        compare(toggles.count, 2)
        mouseClick(button, 20, 20, Qt.RightButton)
        compare(menus.count, 1)
    }

    // --- the panel -----------------------------------------------------------

    function test_the_three_duration_buttons_report_their_minutes() {
        var panel = build(panelComponent, { defaultMinutes: 30 })
        var wanted = []
        panel.durationRequested.connect(function (minutes) { wanted.push(minutes) })
        find(panel, "duration-30")[0].clicked()
        find(panel, "duration-60")[0].clicked()
        find(panel, "duration-0")[0].clicked()
        compare(wanted, [30, 60, 0])
        compare(find(panel, "duration-30")[0].text, "30 minutes")
        compare(find(panel, "duration-60")[0].text, "1 hour")
        compare(find(panel, "duration-0")[0].text, "Until tomorrow")
    }

    function test_the_switch_asks_for_a_toggle() {
        var panel = build(panelComponent, { dndOn: false })
        var asked = 0
        panel.toggleRequested.connect(function () { asked++ })
        var control = find(panel, "dndSwitch")[0]
        mouseClick(control, control.width / 2, control.height / 2)
        compare(asked, 1)
    }

    function test_the_panel_adds_and_removes_allowed_applications() {
        var panel = build(panelComponent, { apps: "Discord" })
        var wanted = []
        panel.appsEdited.connect(function (text) { wanted.push(text) })
        compare(find(panel, "dndApp").length, 1)
        find(panel, "dndAppRemove")[0].clicked()
        find(panel, "dndAppField")[0].text = "Spotify"
        find(panel, "dndAppAdd")[0].clicked()
        compare(wanted, ["", "Discord,Spotify"])
        compare(find(panel, "dndAppField")[0].text, "")
    }

    function test_the_bypass_switch_reports_its_value() {
        var panel = build(panelComponent, { bypass: true })
        var wanted = []
        panel.bypassToggled.connect(function (value) { wanted.push(value) })
        var control = find(panel, "dndBypass")[0]
        mouseClick(control, control.width / 2, control.height / 2)
        compare(wanted, [false])
    }

    function test_the_gear_asks_for_settings() {
        var panel = build(panelComponent, {})
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        find(panel, "popupSettings")[0].clicked()
        compare(asked, 1)
    }
}
