import QtQuick

// A settings page that is built the first time its category is shown, and
// kept from then on, so what the user typed survives switching categories.
Loader {
    id: slot

    // Whether this page's category is the one on screen.
    property bool shown: false
    // The tab a search result asked for. Applied when the page is built and
    // whenever a new result targets it; "" leaves the page on its own tab.
    property string jumpTab: ""
    // The page itself, declared as the child.
    default property Component page
    property bool seen: false

    onShownChanged: if (shown) slot.seen = true
    onJumpTabChanged: if (slot.jumpTab !== "" && slot.item) slot.item.tab = slot.jumpTab
    // A page that fails to build is silent (the log shows nothing): the
    // selftest, which `tests/qml_smoke.sh` runs once per category, must fail.
    onStatusChanged: {
        if (slot.status === Loader.Error && Qt.application.arguments.indexOf("--selftest") !== -1)
            Qt.exit(3)
    }
    Component.onCompleted: if (shown) slot.seen = true

    anchors.fill: parent
    visible: slot.shown
    active: slot.seen
    sourceComponent: slot.page
    onLoaded: if (slot.jumpTab !== "") slot.item.tab = slot.jumpTab
}
