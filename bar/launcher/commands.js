// The commands the launcher runs, as argument lists (never shell strings built
// from the user's text). The QML runs them; tests read them here.
.pragma library

// qalc -t: terse, one line. A leading "-" would read as an option.
function calc(expression) {
    return ["qalc", "-t", expression.charAt(0) === "-" ? " " + expression : expression]
}

// plocate finds anywhere, so ask for more than needed and keep what is under
// $HOME (parseFiles); fd searches $HOME itself.
function files(tool, query, limit, home) {
    if (tool === "plocate")
        return ["plocate", "-i", "-b", "-l", String(limit * 10), "--", query]
    return ["fd", "-i", "-a", "--max-results", String(limit), "--", query, home]
}

// The wallpaper library: every file two levels down (images/, videos/), which
// wallpapers.js filters by extension and sorts by name.
function wallpapers(library) {
    return ["find", library, "-maxdepth", "2", "-type", "f"]
}

// Every application file with its text, so the launcher can see an app
// installed while the shell was running.
function scanDesktop() {
    return ["sh", "-c", "for f in \"$HOME\"/.local/share/applications/*.desktop /usr/local/share/applications/*.desktop /usr/share/applications/*.desktop; do [ -f \"$f\" ] || continue; echo \"@@FILE $f\"; cat \"$f\"; done"]
}

// Which of the two is installed: prints "plocate" or "fd".
function probeFiles() {
    return ["sh", "-c", "command -v plocate >/dev/null 2>&1 && echo plocate || echo fd"]
}

function parseFiles(output, home, limit) {
    var prefix = home.replace(/\/$/, "") + "/"
    return String(output || "").split("\n").filter(function (line) {
        return line.indexOf(prefix) === 0
    }).slice(0, limit)
}

function dirname(path) {
    var at = path.lastIndexOf("/")
    return at <= 0 ? "/" : path.slice(0, at)
}

function open(path) {
    return ["xdg-open", path]
}

function openFolder(path) {
    return ["xdg-open", dirname(path)]
}

// The folder of an installed program (where its executable lives).
function openProgramFolder(program) {
    return ["sh", "-c", "p=$(command -v \"$1\") && xdg-open \"$(dirname \"$(readlink -f \"$p\")\")\"", "sh", program]
}

function copy(text) {
    return ["wl-copy", "--", text]
}

function runInTerminal(command) {
    return ["kitty", "--hold", "sh", "-c", command]
}

function runDetached(command) {
    return ["sh", "-c", command]
}

function clipList() {
    return ["cliphist", "list"]
}

// `cliphist decode` takes the id of an entry and writes what was copied.
function clipCopy(id) {
    return ["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id]
}

// One entry goes away: `delete` reads the id from stdin.
function clipDelete(id) {
    return ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", id]
}

// The whole history.
function clipWipe() {
    return ["cliphist", "wipe"]
}

// A pick for a terminal: the same content without its trailing newlines, so
// it does not submit the command.
function clipCopyTrimmed(id) {
    return ["sh", "-c", "printf '%s' \"$(cliphist decode \"$1\")\" | wl-copy", "sh", id]
}

// The quick toggles: read the state, then flip it.
function wifiState() { return ["nmcli", "radio", "wifi"] }
function wifiSet(on) { return ["nmcli", "radio", "wifi", on ? "on" : "off"] }
function bluetoothState() { return ["bluetoothctl", "show"] }
function bluetoothSet(on) { return ["bluetoothctl", "power", on ? "on" : "off"] }
// The connection popup's Bluetooth tab: a scan stays under the popup's
// patience, and a device joins or leaves by its address.
function bluetoothScan() { return ["bluetoothctl", "--timeout", "5", "scan", "on"] }
function bluetoothConnect(mac) { return ["bluetoothctl", "connect", mac] }
function bluetoothDisconnect(mac) { return ["bluetoothctl", "disconnect", mac] }
function micState() { return ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"] }
function micToggle() { return ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"] }
function airplaneState() { return ["rfkill", "-J"] }

function powerProfile() { return ["powerprofilesctl", "get"] }
function powerSet(profile) { return ["powerprofilesctl", "set", profile] }
function airplaneSet(on) { return ["rfkill", on ? "unblock" : "block", "all"] }

// The screen colour picker: prints the colour under the pointer and exits.
function colorPicker() {
    return ["hyprpicker", "-f", "hex"]
}

// Any text to the clipboard (an emoji, a colour).
function copyText(text) {
    return ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", text]
}

// Typing text into the focused window, for the emoji picker.
function typeText(text) {
    return ["wtype", text]
}

// Pasting a pick into the focused window: Ctrl+V through wtype.
function clipPaste() {
    return ["wtype", "-M", "ctrl", "v", "-m", "ctrl"]
}

// "12<TAB>preview" lines, newest first.
function parseClips(output, limit) {
    var out = []
    String(output || "").split("\n").forEach(function (line) {
        var tab = line.indexOf("\t")
        if (tab > 0 && out.length < limit && line.slice(tab + 1).trim() !== "")
            out.push({ id: line.slice(0, tab), preview: line.slice(tab + 1).trim() })
    })
    return out
}

function settings(binDir, category) {
    return [binDir + "/vitrail-settings", "--category", category]
}

// The Python side of Vitrail; the caller sets PYTHONPATH.
function cli(args) {
    return ["python3", "-m", "vitrail.cli"].concat(args)
}
