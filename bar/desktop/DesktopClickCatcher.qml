import QtQuick

// The desktop's right-click. It only takes the secondary button, so the
// wallpaper layer stays transparent for everything else.
Item {
    id: root

    signal menuRequested(real x, real y)

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: function (mouse) { root.menuRequested(mouse.x, mouse.y) }
    }
}
