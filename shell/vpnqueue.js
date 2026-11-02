.pragma library

// The Connection page talks to vitrail.network over one channel (a request and
// a counter in connection.ini, one answer in network-state.json). A real
// request (a click) keeps the page busy; the background `vpn-probe` does not:
// the page stays operable while it runs. A real request made during a probe
// waits as the one pending request and goes out as soon as the probe's answer
// (or its timeout) lands, so neither is lost.
//
// A state is { probing, busy, queued }: a probe is in flight; the real request
// that is pending or in flight ("" for none); whether `busy` is still waiting
// for the probe. Every function returns { state, send } where `send` is the
// request to put on the channel now ("" for none).

var PROBE = "vpn-probe"

function start() {
    return { probing: false, busy: "", queued: false }
}

// The page is operable: no real request is pending or in flight.
function idle(state) {
    return state.busy === ""
}

function submit(state, request) {
    if (request === PROBE) {
        // Only when nothing else is going on.
        if (state.busy !== "" || state.probing)
            return { state: state, send: "" }
        return { state: { probing: true, busy: "", queued: false }, send: request }
    }
    // One real request at a time.
    if (state.busy !== "")
        return { state: state, send: "" }
    if (state.probing)
        return { state: { probing: true, busy: request, queued: true }, send: "" }
    return { state: { probing: false, busy: request, queued: false }, send: request }
}

// The answer to what is in flight landed, or it timed out.
function answered(state) {
    if (state.probing && state.queued)
        return { state: { probing: false, busy: state.busy, queued: false }, send: state.busy }
    return { state: start(), send: "" }
}

// What is in flight is the real request `busy` (not a probe, not a queued one).
function inFlight(state) {
    return state.busy !== "" && !state.probing
}
