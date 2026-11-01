import QtQuick
import QtTest
import "../../bar/toggles/toggles.js" as Toggles

// The quick toggles read their state from the tools' text.
TestCase {
    name: "Toggles"

    function test_wifi_reads_nmcli() {
        verify(Toggles.wifiOn("enabled\n"))
        verify(!Toggles.wifiOn("disabled\n"))
        verify(!Toggles.wifiOn(""))
    }

    function test_bluetooth_reads_bluetoothctl() {
        verify(Toggles.bluetoothOn("Controller 00:11:22:33:44:55\n  Powered: yes\n"))
        verify(!Toggles.bluetoothOn("Controller 00:11:22:33:44:55\n  Powered: no\n"))
        verify(Toggles.bluetoothPresent("Controller 00:11:22:33:44:55\n"))
        verify(!Toggles.bluetoothPresent(""))
    }

    function test_airplane_mode_is_every_radio_blocked() {
        verify(Toggles.airplaneOn('{"rfkilldevices":[{"soft":"blocked"}]}'))
        verify(!Toggles.airplaneOn('{"rfkilldevices":[{"soft":"unblocked"}]}'))
        verify(!Toggles.airplaneOn('{"rfkilldevices":[{"soft":"blocked"},{"soft":"unblocked"}]}'))
        verify(!Toggles.airplaneOn(""))
    }

    function test_the_microphone_reads_wpctl() {
        verify(Toggles.micMuted("Volume: 1.00 [MUTED]\n"))
        verify(!Toggles.micMuted("Volume: 0.55\n"))
        verify(!Toggles.micMuted(""))
    }
}
