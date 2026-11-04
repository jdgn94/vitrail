// Session actions, in the order they are offered. `label` is an i18n key,
// `icon` a Material Symbol, `shortcut` the letter that runs it in the menu.
// Commands run detached, after the menu has closed.
.pragma library

// How long a confirmation waits before it runs the action.
var SECONDS = 30

var actions = [
    { key: "lock", label: "session.lock", icon: "lock", tone: "primary", shortcut: "l", command: ["hyprlock"] },
    { key: "logout", label: "session.logout", icon: "logout", tone: "primary", shortcut: "o", command: ["hyprctl", "eval", "hl.dispatch(hl.dsp.exit())"] },
    { key: "suspend", label: "session.suspend", icon: "bedtime", tone: "primary", shortcut: "s", command: ["systemctl", "suspend"] },
    { key: "hibernate", label: "session.hibernate", icon: "downloading", tone: "primary", shortcut: "h", command: ["systemctl", "hibernate"] },
    { key: "reboot", label: "session.reboot", icon: "restart_alt", tone: "primary", shortcut: "r", command: ["systemctl", "reboot"] },
    { key: "poweroff", label: "session.poweroff", icon: "power_settings_new", tone: "error", shortcut: "p", command: ["systemctl", "poweroff"] }
]

// The actions that first ask with a countdown: everything that ends the
// session or the machine. Lock and log out do not (a lock keeps the work; a
// log out still goes through the guard below).
var CONFIRM = ["suspend", "hibernate", "reboot", "poweroff"]
// The actions the guard checks first: they cut what is still running.
var INTERRUPT = CONFIRM.concat(["logout"])

function confirmable(key) {
    return CONFIRM.indexOf(key) >= 0
}

function interrupting(key) {
    return INTERRUPT.indexOf(key) >= 0
}

// Seconds left, rounded up, and whether the deadline has passed.
function remaining(deadline, now) {
    return Math.max(0, Math.ceil((deadline - now) / 1000))
}

function finished(deadline, now) {
    return now >= deadline
}

// The actions on offer: hibernate only where the system can do it.
function available(canHibernate) {
    return actions.filter(function (action) {
        return action.key !== "hibernate" || canHibernate
    })
}

function find(key) {
    return actions.filter(function (action) { return action.key === key })[0] || null
}

// Where the focus ring goes after a step (+1 / -1) in a row of `count`
// actions; it wraps around.
function step(index, count, delta) {
    return count <= 0 ? 0 : ((index + delta) % count + count) % count
}

// Index of the action a letter runs in `list`, or -1.
function byShortcut(list, letter) {
    var wanted = String(letter).toLowerCase()
    for (var i = 0; i < list.length; i++) {
        if (list[i].shortcut === wanted)
            return i
    }
    return -1
}
