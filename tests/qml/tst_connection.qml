import QtQuick
import QtTest
import "../../bar/network/connection.js" as Connection

// What the connection panel reads from the system's own tools.
TestCase {
    name: "Connection"

    function test_details_are_read_from_the_script() {
        var details = Connection.details("ADDR 192.168.1.42/24\nGW 192.168.1.1\nDNS 1.1.1.1\n")
        compare(details.address, "192.168.1.42/24")
        compare(details.gateway, "192.168.1.1")
        compare(details.dns, "1.1.1.1")
        compare(Connection.details("").address, "")
    }

    function test_bluetooth_devices_are_listed_once() {
        var list = Connection.bluetoothDevices("Device AA:BB:CC:DD:EE:FF Headphones\nDevice AA:BB:CC:DD:EE:FF Headphones\nDevice 11:22:33:44:55:66 Mouse\n")
        compare(list.length, 2)
        compare(list[0].mac, "AA:BB:CC:DD:EE:FF")
        compare(list[0].name, "Headphones")
        compare(list[1].name, "Mouse")
    }

    function test_a_connected_device_is_marked() {
        var list = Connection.bluetoothDevices("Device AA:BB:CC:DD:EE:FF Headphones\n",
                                               "Device AA:BB:CC:DD:EE:FF\n  Connected: yes\n")
        compare(list[0].connected, true)
    }

    function test_the_power_profile_is_read() {
        compare(Connection.powerProfile("performance\n"), "performance")
        compare(Connection.powerProfile(""), "balanced")
    }
}
