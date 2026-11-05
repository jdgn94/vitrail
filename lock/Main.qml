import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/args.js" as Args

// Vitrail lock screen preview.
//
// Same base as the login screen plus widgets that only make sense when locked.
// The real locker must take ext-session-lock-v1 from a native client; this
// file is the UI half of it.
Item {
    id: root

    // The greeter (or qml6) resizes the root item to the view.
    width: 1280
    height: 800

    property string language: Args.value("--language", "en")
    property string user: Args.value("--user", "")
    property var i18n: Args.json("--i18n", ({ strings: {} }))
    property var strings: (root.i18n.strings || {})[root.language] || ({})
    property var colors: Args.json("--palette", ({}))


    property string grabPath: Args.value("--grab", "")

    Timer {
        interval: 600
        running: root.grabPath !== ""
        onTriggered: root.grabToImage(function (result) {
            result.saveToFile(root.grabPath)
            Qt.quit()
        })
    }

    property date now: new Date()

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    VitrailPalette {
        id: palette
        dark: true
        data: root.colors
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    AuthScreen {
        anchors.fill: parent
        palette: palette
        username: root.user
        editableUsername: false
        title: root.t("auth.unlock")
        userLabel: root.t("auth.username")
        passwordLabel: root.t("auth.password")
        actionLabel: root.t("auth.unlock")
        keyboardLayout: root.language
        keyboardTitle: root.t("keyboard.osk")
        onSubmitted: function (username, password) {
            console.log("unlock submitted:", username)
        }

        // Lock-only widgets.
        header: ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatTime(root.now, "HH:mm")
                color: palette.foreground
                font.pixelSize: 40
                font.weight: Font.Light
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(root.now, "dddd d MMMM")
                color: palette.muted
                font.pixelSize: 12
            }
        }
    }
}
