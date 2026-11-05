// The on-screen keyboard's languages and key rows. Kept beside the composed
// component so the login, the lock, the bar and the gallery draw the same
// layouts; the host decides how a key is written.
.pragma library

var LANGUAGES = ["es", "en", "de", "fr", "it", "pt"]

// Three letter rows per language. An unknown language falls back to en.
var LETTERS = {
    en: ["qwertyuiop", "asdfghjkl", "zxcvbnm"],
    es: ["qwertyuiop", "asdfghjklñ", "zxcvbnm"],
    de: ["qwertzuiopü", "asdfghjklöä", "yxcvbnm"],
    fr: ["azertyuiop", "qsdfghjklm", "wxcvbn"],
    it: ["qwertyuiop", "asdfghjklòàù", "zxcvbnm"],
    pt: ["qwertyuiop", "asdfghjklç", "zxcvbnm"]
}

function normalise(layout) {
    return LETTERS[layout] ? layout : "en"
}

function rows(layout) {
    return LETTERS[normalise(layout)].map(function (row) {
        return row.split("")
    })
}

function digits() {
    return "1234567890".split("")
}
