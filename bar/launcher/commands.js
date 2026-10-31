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
