// The launcher's initial state: one object with every field an opening puts
// back, so `reset()` has a single source to follow.
.pragma library
.import "query.js" as Query

// `initialMode` is the launcher's mode request (`launcher open <mode>`); it
// starts on that mode's prefix and otherwise on the mixed view.
function start(initialMode) {
    var prefix = initialMode && Query.PREFIXES[initialMode] ? Query.PREFIXES[initialMode] : ""
    return {
        text: prefix,
        current: 0,
        tab: "all",
        expanded: false,
        menu: null,
        menuCurrent: 0,
        calcQuery: "",
        calcText: "",
        fileQuery: "",
        fileItems: [],
        clips: [],
        wallpaperFiles: [],
        wallpaperLoaded: false,
        modeBefore: "",
        selected: null,
        tip: null
    }
}
