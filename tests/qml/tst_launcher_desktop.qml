import QtQuick
import QtTest
import "../../bar/launcher/desktop.js" as Desktop

// Reading .desktop files without the shell's own index, so the launcher can
// pick up an app installed while it was running.
TestCase {
    name: "LauncherDesktop"

    readonly property string sample: "[Desktop Entry]\nType=Application\nName=Vitrail Probe\nGenericName=Probe\n" +
                                     "Comment=A test\nExec=/usr/bin/true %U\nIcon=applications-utilities\n" +
                                     "Keywords=probe;test;\nCategories=Utility;System;\nNoDisplay=false\n" +
                                     "Actions=New;\n\n[Desktop Action New]\nName=New\nExec=/usr/bin/true --new\n"

    function test_a_file_is_read() {
        var entry = Desktop.parse(sample, "vitrail-probe.desktop")
        compare(entry.id, "vitrail-probe.desktop")
        compare(entry.name, "Vitrail Probe")
        compare(entry.genericName, "Probe")
        compare(entry.comment, "A test")
        compare(entry.execString, "/usr/bin/true %U")
        compare(entry.icon, "applications-utilities")
        compare(entry.keywords, ["probe", "test"])
        compare(entry.categories, ["Utility", "System"])
        compare(entry.noDisplay, false)
        compare(entry.actions, ["New"])
    }

    function test_only_the_desktop_entry_section_counts() {
        var entry = Desktop.parse(sample, "x.desktop")
        compare(entry.name, "Vitrail Probe")
    }

    function test_no_display_is_read() {
        compare(Desktop.parse("[Desktop Entry]\nName=Hidden\nNoDisplay=true\n", "h.desktop").noDisplay, true)
    }

    function test_only_the_unknown_entries_are_returned() {
        var scanned = [{ id: "a.desktop", name: "A" }, { id: "b.desktop", name: "B" }]
        var known = [{ id: "a.desktop" }]
        compare(Desktop.missing(scanned, known).length, 1)
        compare(Desktop.missing(scanned, known)[0].id, "b.desktop")
        compare(Desktop.missing(scanned, []).length, 2)
    }

    function test_a_scan_is_split_into_entries() {
        var output = "@@FILE /tmp/a.desktop\n[Desktop Entry]\nName=A\n@@FILE /tmp/b.desktop\n[Desktop Entry]\nName=B\n"
        var list = Desktop.parseScan(output)
        compare(list.length, 2)
        compare(list[0].id, "a.desktop")
        compare(list[0].name, "A")
        compare(list[1].name, "B")
        compare(Desktop.parseScan("").length, 0)
    }

    function test_the_command_drops_the_field_codes() {
        compare(Desktop.command("/usr/bin/app %U"), "/usr/bin/app")
        compare(Desktop.command("env A=1 app %f %F"), "env A=1 app")
        compare(Desktop.command(""), "")
    }
}
