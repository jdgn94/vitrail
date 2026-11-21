pragma Singleton
import QtQuick

// Stand-in for the real module, which only exists inside the shell: enough for
// the components under test to load.
QtObject {
    function iconPath(name, check) {
        return ""
    }
}
