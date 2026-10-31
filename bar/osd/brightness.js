// Brightness of the monitors, as `vitrail brightness list` reports it:
// { status, devices: [{ name, kind: "ddc" | "backlight", bus, device, percent,
// max }] }. Pure, tested in tests/qml/tst_osd.qml.
.pragma library

function clamp(percent) {
    var n = Math.round(Number(percent))
    return isNaN(n) ? 0 : Math.max(0, Math.min(100, n))
}

// One key press: direction +1 / -1 of `amount` percent.
function step(percent, direction, amount) {
    return clamp(Math.round(percent) + direction * amount)
}

// The main slider shows the mean of the displays.
function level(devices) {
    if (!devices.length)
        return 0
    var sum = devices.reduce(function (total, device) { return total + device.percent }, 0)
    return clamp(sum / devices.length)
}

// The program that sets a display to `percent`.
function command(device, percent) {
    if (device.kind === "ddc") {
        var raw = Math.round(clamp(percent) * (device.max || 100) / 100)
        return ["ddcutil", "setvcp", "10", String(raw), "--bus", String(device.bus), "--noverify"]
    }
    return ["brightnessctl", "--quiet", "--device=" + device.device, "set", clamp(percent) + "%"]
}

function parse(text) {
    try {
        var data = JSON.parse(text)
        return { status: data.status || "none", devices: data.devices || [] }
    } catch (error) {
        return { status: "none", devices: [] }
    }
}

// Why the slider is off, as an i18n key; "" when it works.
function reason(status) {
    return {
        ok: "",
        access: "osd.brightnessAccess",
        missing: "osd.brightnessMissing",
        loading: "osd.brightnessLoading"
    }[status] ?? "osd.brightnessNone"
}
