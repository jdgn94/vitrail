import QtQuick
import QtTest
import "../../kit"

// AuthScreen owns the password field, so its on-screen keyboard writes into
// that field directly. Login and lock both use it; opening the keyboard there
// must reveal the same shared component.
TestCase {
    id: testCase

    name: "AuthKeyboard"
    when: windowShown
    visible: true
    width: 900
    height: 900

    VitrailPalette {
        id: palette
    }

    Component {
        id: auth

        AuthScreen {
            width: 900
            height: 900
            editableUsername: false
            username: "juan"
            title: "Unlock"
            keyboardTitle: "Keyboard"
            keyboardLayout: "es"
        }
    }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function fromFile(path) {
        var component = Qt.createComponent(path)
        verify(component.status === Component.Ready, component.errorString())
        return createTemporaryObject(component, testCase)
    }

    function authScreen(item) {
        if (!item)
            return null
        if (item.keyboardItem !== undefined && item.passwordText !== undefined)
            return item
        for (var i = 0; i < item.children.length; i++) {
            var found = authScreen(item.children[i])
            if (found)
                return found
        }
        return null
    }

    function test_it_is_closed_then_writes_into_the_password_field() {
        var screen = createTemporaryObject(auth, testCase)
        verify(screen)
        compare(screen.keyboardOpen, false)

        screen.keyboardOpen = true
        verify(screen.keyboardItem.visible)

        screen.keyboardItem.press("a")
        screen.keyboardItem.press("shift")
        screen.keyboardItem.press("b")
        compare(screen.passwordText, "aB")

        screen.keyboardItem.press("backspace")
        compare(screen.passwordText, "a")

        screen.keyboardItem.cycle()
        compare(screen.keyboardLayout, "en")

        screen.keyboardOpen = false
        compare(screen.keyboardItem.visible, false)
    }

    function test_login_and_lock_open_the_same_keyboard() {
        var login = fromFile("../../login/Main.qml")
        verify(login)
        var loginAuth = authScreen(login)
        verify(loginAuth)
        loginAuth.keyboardOpen = true
        verify(loginAuth.keyboardItem.visible)
        loginAuth.keyboardItem.press("l")
        compare(loginAuth.passwordText, "l")

        var lock = fromFile("../../lock/Main.qml")
        verify(lock)
        var lockAuth = authScreen(lock)
        verify(lockAuth)
        lockAuth.keyboardOpen = true
        verify(lockAuth.keyboardItem.visible)
        lockAuth.keyboardItem.press("k")
        compare(lockAuth.passwordText, "k")
    }
}
