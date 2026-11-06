.pragma library

// The shell's fullscreen and edit-mode policy, in one place so the QML tests
// can check the paths without a compositor:
//
// - a fullscreen window takes the notification panel and its toasts away;
// - the in-place editor does the same while it is open;
// - the volume OSD is never taken away (a fullscreen app keeps it, and so does
//   the editor);
// - the bar and its frame are not drawn in the editor, but their window stays
//   alive so the OSD and the outer frame can use it.

function notificationsAllowed(fullscreen, editing) {
    return !fullscreen && !editing
}

function toastsAllowed(fullscreen, editing) {
    return !fullscreen && !editing
}

function barDrawn(fullscreenHidden, editing) {
    return !fullscreenHidden && !editing
}

// The bar's layer window is kept for the OSD: the bar and the frame may stop
// drawing (a fullscreen window, the editor), but the surface stays alive so the
// OSD's host is never taken away with them.
function barWindowAlive() {
    return true
}

function osdAllowed() {
    return true
}
