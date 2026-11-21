import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/disks"
import "../../bar/disks/disks.js" as Disks

// The disks element: the visibility rule, the ignore list, the button's
// states per device state, the popup's cards and the actions it asks the shell
// to run, and the automount rule that never mounts the same drive twice.
TestCase {
    id: testCase

    name: "Disks"
    when: windowShown
    visible: true
    width: 420
    height: 760

    readonly property var strings: ({
        "bar.widget.disks": "Drives",
        "bar.disks.drives": "%1 drives",
        "bar.disks.unavailable": "Removable drives unavailable",
        "bar.disks.unreadable": "Cannot read the removable drives.",
        "bar.disks.empty": "No removable drives are connected.",
        "bar.disks.mount": "Mount",
        "bar.disks.unmount": "Unmount",
        "bar.disks.eject": "Eject",
        "bar.disks.open": "Open",
        "bar.disks.mountPoint": "Mounted at %1",
        "bar.disks.notMounted": "Not mounted",
        "bar.disks.reason.mounted": "Mount and Eject need the drive unmounted.",
        "bar.disks.reason.unmounted": "Unmount and Open need the drive mounted.",
        "bar.disks.reason.mountpoint": "The drive has no mount point to open.",
        "bar.disks.reason.busy": "Waiting for the drive…"
    })

    readonly property real gb: 1024 * 1024 * 1024

    function device(overrides) {
        var base = {
            name: "/dev/sdb1",
            label: "KINGSTON",
            uuid: "1A2B-3C4D",
            fstype: "vfat",
            size: 16 * testCase.gb,
            model: "USB DISK 3.0",
            transport: "usb",
            mounted: false,
            mountpoint: "",
            used: null,
            free: null
        }
        for (var key in overrides)
            base[key] = overrides[key]
        return base
    }

    function snapshot(devices) {
        return { devices: devices, total: devices.length }
    }

    function mounted(overrides) {
        return device(Object.assign({
            mounted: true,
            mountpoint: "/run/media/juan/KINGSTON",
            used: 4 * testCase.gb,
            free: 12 * testCase.gb
        }, overrides || {}))
    }

    Component {
        id: buttonComponent

        DisksButton {
            width: 40
            height: 40
            strings: testCase.strings
        }
    }

    Component {
        id: panelComponent

        DisksPanel {
            width: 400
            strings: testCase.strings
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: actions; signalName: "actionRequested" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    // Every descendant with that objectName.
    function descendants(item, name, found) {
        var out = found || []
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.objectName === name)
                out.push(child)
            descendants(child, name, out)
        }
        return out
    }

    // --- the plain logic -----------------------------------------------------

    function test_a_snapshot_is_ready_when_it_carries_a_device_list() {
        compare(Disks.ready(snapshot([])), true)
        compare(Disks.ready(snapshot([device({})])), true)
        compare(Disks.ready({}), false)
        compare(Disks.ready({ error: "unreadable" }), false)
        compare(Disks.ready(null), false)
        compare(Disks.visibleDevices({ error: "unreadable" }, ""), [])
    }

    function test_the_ignore_list_is_labels_and_uuids_without_case() {
        compare(Disks.parseIgnore(""), [])
        compare(Disks.parseIgnore("not json"), [])
        compare(Disks.parseIgnore('{"label":"KINGSTON"}'), [])
        compare(Disks.parseIgnore('[" KINGSTON ","1a2b-3c4d","",3]'), ["KINGSTON", "1a2b-3c4d"])
        compare(Disks.parseIgnore('["KINGSTON","kingston"]'), ["KINGSTON"])

        compare(Disks.withIgnore("", "KINGSTON", true), '["KINGSTON"]')
        compare(Disks.withIgnore('["KINGSTON"]', "kingston", true), '["kingston"]')
        compare(Disks.withIgnore('["KINGSTON","Backup"]', "KINGSTON", false), '["Backup"]')
        compare(Disks.withIgnore('["KINGSTON"]', "  ", true), '["KINGSTON"]')
    }

    function test_an_ignored_device_appears_in_neither_the_button_nor_the_popup() {
        var one = device({})
        var two = device({ name: "/dev/sdc1", label: "Backup", uuid: "9F8E", mounted: true,
                           mountpoint: "/run/media/juan/Backup", used: 1, free: 1 })
        compare(Disks.visibleDevices(snapshot([one, two]), "").length, 2)
        compare(Disks.visibleDevices(snapshot([one, two]), '["kingston"]').length, 1)
        compare(Disks.visibleDevices(snapshot([one, two]), '["9f8e"]')[0].name, "/dev/sdb1")
        compare(Disks.visibleDevices(snapshot([one]), '["KINGSTON","1A2B-3C4D"]').length, 0)
    }

    function test_a_device_is_named_by_its_label_then_its_model_then_its_name() {
        compare(Disks.nameOf(device({})), "KINGSTON")
        compare(Disks.nameOf(device({ label: "", model: "Cruzer Blade" })), "Cruzer Blade")
        compare(Disks.nameOf(device({ label: "", model: "", name: "/dev/sdd" })), "sdd")
        compare(Disks.nameOf(null), "")
    }

    function test_sizes_read_in_units_a_person_knows() {
        compare(Disks.humanSize(0), "0 B")
        compare(Disks.humanSize(512), "512 B")
        compare(Disks.humanSize(1536), "1.5 KB")
        compare(Disks.humanSize(16 * testCase.gb), "16.0 GB")
        compare(Disks.humanSize(undefined), "--")
        compare(Disks.space(mounted({})), "4.0 GB / 16.0 GB")
        compare(Disks.space(device({})), "16.0 GB")
        compare(Disks.usage([mounted({})]), "4.0 GB / 16.0 GB")
        compare(Disks.usage([device({})]), "16.0 GB")
        compare(Disks.usage([mounted({})]), "4.0 GB / 16.0 GB")
    }

    function test_each_action_is_allowed_by_the_devices_own_state() {
        var unmounted = device({})
        var mountedOne = mounted({})
        compare(Disks.allowed(unmounted, "mount"), true)
        compare(Disks.allowed(unmounted, "eject"), true)
        compare(Disks.allowed(unmounted, "unmount"), false)
        compare(Disks.allowed(unmounted, "open"), false)
        compare(Disks.allowed(mountedOne, "unmount"), true)
        compare(Disks.allowed(mountedOne, "open"), true)
        compare(Disks.allowed(mountedOne, "mount"), false)
        compare(Disks.allowed(mountedOne, "eject"), false)
        compare(Disks.allowed(null, "mount"), false)
        compare(Disks.allowed({ mounted: true, name: "/dev/sdb1", mountpoint: "" }, "open"), false)
    }

    function test_a_disabled_action_explains_itself() {
        compare(Disks.reasons(device({}), false), ["bar.disks.reason.unmounted"])
        compare(Disks.reasons(mounted({}), false), ["bar.disks.reason.mounted"])
        compare(Disks.reasons(mounted({ mountpoint: "" }), false), ["bar.disks.reason.mountpoint"])
        compare(Disks.reasons(device({}), true),
                ["bar.disks.reason.busy", "bar.disks.reason.unmounted"])
    }

    function test_automount_only_mounts_a_new_unmounted_visible_drive() {
        var one = device({})
        compare(Disks.automountCandidates([], snapshot([one]), "", false), [])
        compare(Disks.automountCandidates([], snapshot([one]), "", true), ["/dev/sdb1"])
        compare(Disks.automountCandidates(["/dev/sdb1"], snapshot([one]), "", true), [])
        compare(Disks.automountCandidates([], snapshot([mounted({})]), "", true), [])
        compare(Disks.automountCandidates([], snapshot([one]), '["KINGSTON"]', true), [])
        compare(Disks.automountCandidates([], { error: "unreadable" }, "", true), [])
    }

    function test_a_drive_that_goes_away_can_be_mounted_again_when_it_returns() {
        var one = device({})
        compare(Disks.retainAttempted(["/dev/sdb1", "/dev/sdc1"], snapshot([one])), ["/dev/sdb1"])
        var forgotten = Disks.retainAttempted(["/dev/sdb1"], snapshot([]))
        compare(forgotten, [])
        compare(Disks.automountCandidates(forgotten, snapshot([one]), "", true), ["/dev/sdb1"])
    }

    // --- the button ----------------------------------------------------------

    function test_the_element_is_only_on_the_bar_while_a_drive_is_plugged_in() {
        var item = make(buttonComponent)
        compare(item.showMode, "active")
        compare(item.active, false)
        compare(item.shown, false)
        item.snapshot = snapshot([device({})])
        compare(item.active, true)
        compare(item.shown, true)
        item.showMode = "always"
        item.snapshot = snapshot([])
        compare(item.shown, true)
    }

    function test_the_tooltip_names_the_drive_and_its_used_space() {
        var item = make(buttonComponent)
        item.snapshot = snapshot([device({})])
        compare(item.icon, "storage")
        compare(item.tooltip, "KINGSTON")
        compare(item.tooltipDetail, "16.0 GB")
        item.snapshot = snapshot([mounted({})])
        compare(item.tooltipDetail, "4.0 GB / 16.0 GB")
    }

    function test_two_drives_are_a_count_and_the_space_of_both() {
        var item = make(buttonComponent)
        item.snapshot = snapshot([
            mounted({}),
            device({ name: "/dev/sdc1", label: "Backup", uuid: "9F8E", size: 16 * testCase.gb })
        ])
        compare(item.active, true)
        compare(item.tooltip, "2 drives")
        compare(item.tooltipDetail, "4.0 GB / 32.0 GB")
    }

    function test_an_ignored_drive_does_not_keep_the_element_in_the_bar() {
        var item = make(buttonComponent)
        item.snapshot = snapshot([device({})])
        item.ignore = '["KINGSTON"]'
        compare(item.active, false)
        compare(item.shown, false)
        item.ignore = ""
        compare(item.active, true)
    }

    function test_without_a_usable_snapshot_the_button_says_unavailable() {
        var item = make(buttonComponent)
        item.snapshot = { error: "unreadable" }
        compare(item.active, false)
        compare(item.tooltip, "Drives")
        compare(item.tooltipDetail, "Removable drives unavailable")
    }

    function test_a_left_click_opens_the_popup() {
        var item = make(buttonComponent)
        var clicks = 0
        item.clicked.connect(function () { clicks++ })
        mouseClick(item, 20, 20, Qt.LeftButton)
        compare(clicks, 1)
    }

    // --- the popup -----------------------------------------------------------

    function test_the_popup_draws_one_card_per_visible_drive() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([mounted({}), device({ name: "/dev/sdc1", label: "Backup", uuid: "9F8E" })])
        compare(descendants(panel, "drive").length, 2)
        compare(descendants(panel, "usage").length, 2)
        panel.ignore = '["KINGSTON"]'
        compare(descendants(panel, "drive").length, 1)
        panel.snapshot = snapshot([])
        compare(findChild(panel, "empty").visible, true)
    }

    function test_a_mounted_card_offers_unmount_and_open() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([mounted({})])
        compare(findChild(panel, "unmount").enabled, true)
        compare(findChild(panel, "open").enabled, true)
        compare(findChild(panel, "mount").enabled, false)
        compare(findChild(panel, "eject").enabled, false)
        compare(findChild(panel, "mount").visible, true)
        compare(findChild(panel, "eject").visible, true)
        compare(findChild(panel, "reason").text, "Mount and Eject need the drive unmounted.")
        compare(findChild(panel, "mountPoint").text, "Mounted at /run/media/juan/KINGSTON")
    }

    function test_an_unmounted_card_offers_mount_and_eject() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([device({})])
        compare(findChild(panel, "mount").enabled, true)
        compare(findChild(panel, "eject").enabled, true)
        compare(findChild(panel, "unmount").enabled, false)
        compare(findChild(panel, "open").enabled, false)
        compare(findChild(panel, "reason").text, "Unmount and Open need the drive mounted.")
        compare(findChild(panel, "mountPoint").text, "Not mounted")
        compare(findChild(panel, "usageText").text, "16.0 GB")
    }

    function test_every_action_leaves_as_the_shells_argv() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([mounted({})])
        actions.target = panel
        actions.clear()

        findChild(panel, "unmount").clicked()
        compare(actions.signalArguments[0][0], "unmount")
        compare(actions.signalArguments[0][1], "/dev/sdb1")

        findChild(panel, "open").clicked()
        compare(actions.signalArguments[1][0], "open")
        compare(actions.signalArguments[1][1], "/run/media/juan/KINGSTON")

        panel.snapshot = snapshot([device({})])
        findChild(panel, "mount").clicked()
        compare(actions.signalArguments[2][0], "mount")
        compare(actions.signalArguments[2][1], "/dev/sdb1")

        findChild(panel, "eject").clicked()
        compare(actions.signalArguments[3][0], "eject")
        compare(actions.signalArguments[3][1], "/dev/sdb1")
    }

    function test_a_failed_action_is_a_calm_line_with_its_text() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([device({})])
        compare(findChild(panel, "actionError").visible, false)
        panel.error = "Error: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorized"
        compare(findChild(panel, "actionError").visible, true)
        compare(findChild(panel, "actionError").text,
                "Error: GDBus.Error:org.freedesktop.UDisks2.Error.NotAuthorized")
        panel.error = ""
        compare(findChild(panel, "actionError").visible, false)
    }

    function test_a_running_action_disables_the_buttons_and_says_why() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot([device({})])
        panel.busy = true
        compare(findChild(panel, "mount").enabled, false)
        compare(findChild(panel, "eject").enabled, false)
        compare(findChild(panel, "reason").text, "Waiting for the drive…")
    }

    function test_an_unreadable_snapshot_says_so_instead_of_drawing_cards() {
        var panel = make(panelComponent)
        panel.snapshot = { error: "unreadable" }
        compare(findChild(panel, "unavailable").visible, true)
        compare(descendants(panel, "drive").length, 0)
    }

    function test_the_panel_gear_asks_for_settings() {
        var panel = make(panelComponent)
        var gear = findChild(panel, "popupSettings")
        verify(gear !== null)
        var asked = 0
        panel.settingsRequested.connect(function () { asked++ })
        mouseClick(gear, gear.width / 2, gear.height / 2)
        compare(asked, 1)
    }
}
