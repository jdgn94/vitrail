import QtQuick
import "kit"
import "kit/args.js" as Args

// Vitrail login screen (SDDM theme entry point).
//
// Same base as the lock screen. Authentication is not wired yet: `submitted`
// is where the SDDM login call will go.
Item {
    id: root

    // The greeter (or qml6) resizes the root item to the view.
    width: 1280
    height: 800

    property string language: Args.value("--language", "en")
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

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    VitrailPalette {
        id: palette
        dark: true
        data: root.colors
    }

    AuthScreen {
        anchors.fill: parent
        palette: palette
        username: ""
        editableUsername: true
        title: root.t("auth.signIn")
        userLabel: root.t("auth.username")
        passwordLabel: root.t("auth.password")
        actionLabel: root.t("auth.signIn")
        keyboardLayout: root.language
        keyboardTitle: root.t("keyboard.osk")
        onSubmitted: function (username, password) {
            console.log("login submitted:", username)
        }
    }
}
