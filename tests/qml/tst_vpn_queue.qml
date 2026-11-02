import QtQuick
import QtTest
import "../../shell/vpnqueue.js" as Queue

// One channel to the helper: the background probe never makes the page busy,
// and a request made during it waits for its answer.
TestCase {
    name: "VpnQueue"

    function test_a_probe_on_an_idle_page_goes_out_and_leaves_the_page_operable() {
        var step = Queue.submit(Queue.start(), "vpn-probe")
        compare(step.send, "vpn-probe")
        compare(step.state.probing, true)
        compare(Queue.idle(step.state), true)
        compare(Queue.inFlight(step.state), false)
    }

    function test_a_probe_is_skipped_while_a_real_request_is_busy_or_pending_or_a_probe_runs() {
        var busy = Queue.submit(Queue.start(), "vpn-up:a").state
        compare(Queue.submit(busy, "vpn-probe").send, "")
        var probing = Queue.submit(Queue.start(), "vpn-probe").state
        compare(Queue.submit(probing, "vpn-probe").send, "")
        var pending = Queue.submit(probing, "vpn-up:a").state
        compare(Queue.submit(pending, "vpn-probe").send, "")
    }

    function test_a_real_request_on_an_idle_page_goes_out_and_busies_it() {
        var step = Queue.submit(Queue.start(), "vpn-up:a")
        compare(step.send, "vpn-up:a")
        compare(Queue.idle(step.state), false)
        compare(Queue.inFlight(step.state), true)
    }

    function test_a_request_during_a_probe_waits_and_busies_the_page() {
        var probing = Queue.submit(Queue.start(), "vpn-probe").state
        var step = Queue.submit(probing, "vpn-up:a")
        compare(step.send, "")
        compare(step.state.busy, "vpn-up:a")
        compare(Queue.idle(step.state), false)
        compare(Queue.inFlight(step.state), false)
    }

    function test_only_one_real_request_is_pending() {
        var queued = Queue.submit(Queue.submit(Queue.start(), "vpn-probe").state, "vpn-up:a").state
        var again = Queue.submit(queued, "vpn-down:b")
        compare(again.send, "")
        compare(again.state.busy, "vpn-up:a")
    }

    function test_the_probe_answer_sends_the_pending_request() {
        var queued = Queue.submit(Queue.submit(Queue.start(), "vpn-probe").state, "vpn-up:a").state
        var step = Queue.answered(queued)
        compare(step.send, "vpn-up:a")
        compare(step.state.probing, false)
        compare(Queue.inFlight(step.state), true)
        // And its own answer frees the page.
        var done = Queue.answered(step.state)
        compare(done.send, "")
        compare(Queue.idle(done.state), true)
    }

    function test_a_probe_answer_with_nothing_waiting_just_ends_the_probe() {
        var step = Queue.answered(Queue.submit(Queue.start(), "vpn-probe").state)
        compare(step.send, "")
        compare(step.state, Queue.start())
    }

    function test_a_real_answer_or_timeout_frees_the_page() {
        var step = Queue.answered(Queue.submit(Queue.start(), "refresh").state)
        compare(step.state, Queue.start())
        compare(step.send, "")
    }
}
