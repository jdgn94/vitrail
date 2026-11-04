import QtQuick
import QtTest
import "../../bar/network/connection.js" as Connection

// What the bar reads from the system's own tools for the connection chip.
TestCase {
    name: "Connection"

    function test_the_power_profile_is_read() {
        compare(Connection.powerProfile("performance\n"), "performance")
        compare(Connection.powerProfile(""), "balanced")
    }
}
