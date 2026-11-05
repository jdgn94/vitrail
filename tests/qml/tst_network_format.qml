import QtQuick
import QtTest
import "../../bar/network/format.js" as Format

// How the bar writes the link's latency and traffic: short, and never a made-up
// number for something that was not measured.
TestCase {
    name: "NetworkFormat"

    function test_rates_use_bytes_kilobytes_and_megabytes() {
        compare(Format.rate(0), "0 B/s")
        compare(Format.rate(999), "999 B/s")
        compare(Format.rate(1000), "1.0 kB/s")
        compare(Format.rate(1200), "1.2 kB/s")
        compare(Format.rate(80000), "80 kB/s")
        compare(Format.rate(1250000), "1.3 MB/s")
        compare(Format.rate(2400000000), "2.4 GB/s")
    }

    function test_a_rate_that_was_not_measured_is_empty() {
        compare(Format.rate(null), "")
        compare(Format.rate(undefined), "")
        compare(Format.rate(-1), "")
        compare(Format.rate(NaN), "")
    }

    function test_latency_is_whole_milliseconds() {
        compare(Format.latency(12.4), "12 ms")
        compare(Format.latency(12.6), "13 ms")
        compare(Format.latency(null), "")
        compare(Format.latency(undefined), "")
    }

    function test_the_summary_reads_latency_then_download_then_upload() {
        compare(Format.summary({ latency: 12.4, traffic: { rx: 1200000, tx: 80000 } }),
                "12 ms · ↓ 1.2 MB/s ↑ 80 kB/s")
        compare(Format.summary({ latency: 12.4, traffic: { rx: 1200, tx: null } }), "12 ms · ↓ 1.2 kB/s")
        compare(Format.summary({ latency: null, traffic: { rx: null, tx: 80 } }), "↑ 80 B/s")
        compare(Format.summary({ latency: 8, traffic: { rx: null, tx: null } }), "8 ms")
    }

    function test_nothing_measured_is_no_line_at_all() {
        compare(Format.summary(null), "")
        compare(Format.summary({}), "")
        compare(Format.summary({ latency: null, traffic: { rx: null, tx: null } }), "")
    }
}
