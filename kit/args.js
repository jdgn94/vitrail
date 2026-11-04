// Shared helpers for the QML entry points.
.pragma library

// Reads `--name value` from the runtime arguments.
function value(name, fallback) {
    var args = Qt.application.arguments
    for (var index = 0; index < args.length; index++) {
        if (args[index] === name && index + 1 < args.length)
            return args[index + 1]
    }
    return fallback
}

// Parses a JSON argument, returning `fallback` on any error.
function json(name, fallback) {
    try {
        return JSON.parse(value(name, JSON.stringify(fallback)))
    } catch (error) {
        return fallback
    }
}

// Parses the JSON file named by `--<file>`; when it is missing or unreadable,
// falls back to the JSON in `--<arg>` (a large document travels as a file).
function jsonFile(fileName, argName, fallback) {
    var path = value(fileName, "")
    if (path !== "") {
        try {
            var request = new XMLHttpRequest()
            request.open("GET", "file://" + path, false)
            request.send()
            return JSON.parse(request.responseText)
        } catch (error) {
            // Fall through to the argument.
        }
    }
    return json(argName, fallback)
}
