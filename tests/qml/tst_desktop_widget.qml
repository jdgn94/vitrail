import QtQuick
import QtTest
import "../../bar/widgets"
import "../../bar/notes"
import "../../bar/layouts.js" as Layouts
import "../../kit"

// The desktop host (bar/widgets/DesktopWidget.qml) resolves a placed widget's
// typography (bar/layouts.js) into the real component: the family, weight and
// italic reach every VitrailText it draws, and empty values keep the variant's
// own look.
TestCase {
    id: testCase

    name: "DesktopWidgetTypography"
    when: windowShown
    visible: true
    width: 700
    height: 700

    VitrailPalette {
        id: palette
    }

    readonly property var weather: ({
        location: { name: "Madrid" },
        units: { temperature: "°C", humidity: "%", wind: "km/h" },
        current: { temperature: 18, humidity: 60, wind: 10, condition: "Clear sky" },
        daily: [
            { date: "2026-11-06", high: 20, low: 9, condition: "Overcast" }
        ]
    })

    Component {
        id: clockHost

        DesktopWidget {
            width: 320
            height: 120
            widgetId: "clock"
            now: new Date(2026, 10, 6, 14, 5)
        }
    }

    Component {
        id: notesWidget

        QuickNotes {
            width: 320
            height: 200
            text: '["one note","second note"]'
            strings: ({})
        }
    }

    Component {
        id: weatherHost

        DesktopWidget {
            width: 320
            height: 240
            widgetId: "weather"
            weather: testCase.weather
        }
    }

    Component {
        id: imageHost

        DesktopWidget {
            width: 380
            height: 240
            widgetId: "image"
            style: "contain"
            imageSource: ""
        }
    }

    function initTestCase() {
        VitrailTokens.configure({
            surface: palette.surface,
            surfaceHigh: palette.surfaceHigh,
            foreground: palette.foreground,
            muted: palette.muted,
            primary: palette.primary,
            accentForeground: palette.accentForeground,
            info: palette.info,
            infoForeground: palette.infoForeground,
            error: palette.error,
            errorForeground: palette.errorForeground
        }, true, "glass", ({}))
    }

    function test_the_clock_text_takes_the_family_weight_and_italic() {
        var host = createTemporaryObject(clockHost, testCase, {
            fontFamily: "DejaVu Sans", fontWeight: "bold", italic: true
        })
        verify(host !== null)
        var time = findChild(host, "dashboardClock")
        verify(time !== null)
        compare(time.font.family, "DejaVu Sans")
        compare(time.font.weight, Font.Bold)
        compare(time.font.italic, true)
        var date = findChild(host, "dashboardClockDate")
        compare(date.font.family, "DejaVu Sans")
        compare(date.font.weight, Font.Bold)
        compare(date.font.italic, true)
    }

    function test_empty_typography_keeps_the_variant_look() {
        var host = createTemporaryObject(clockHost, testCase, {})
        var time = findChild(host, "dashboardClock")
        compare(time.font.family, VitrailTokens.fontFamily)
        compare(time.font.weight, VitrailStyle.resolve("text", "display").weight)
        compare(time.font.italic, false)
    }

    function test_the_notes_lines_take_the_override() {
        var host = createTemporaryObject(notesWidget, testCase, {
            fontFamily: "DejaVu Sans", fontWeight: "medium", italic: true
        })
        var note = findChild(host, "quickNote0")
        verify(note !== null)
        compare(note.text, "one note")
        compare(note.font.family, "DejaVu Sans")
        compare(note.font.weight, Font.Medium)
        compare(note.font.italic, true)
    }

    function test_a_forecast_delegate_takes_the_override_too() {
        var host = createTemporaryObject(weatherHost, testCase, {
            fontFamily: "DejaVu Sans", fontWeight: "regular", italic: true
        })
        var temperature = findChild(host, "dashboardWeatherTemperature")
        compare(temperature.font.family, "DejaVu Sans")
        compare(temperature.font.weight, Font.Normal)
        compare(temperature.font.italic, true)
        var day = findChild(host, "dashboardWeatherDayCondition0")
        verify(day !== null)
        compare(day.font.family, "DejaVu Sans")
        compare(day.font.weight, Font.Normal)
        compare(day.font.italic, true)
    }

    function test_the_image_widget_loads_with_its_variant() {
        var host = createTemporaryObject(imageHost, testCase, {})
        verify(host !== null)
        var image = findChild(host, "desktopImage")
        verify(image !== null)
        compare(image.variant, "contain")
        verify(image.implicitHeight > 0)
    }

    function test_the_document_typography_reaches_the_host() {
        var text = JSON.stringify({
            monitors: {
                "DP-1": {
                    widgets: [{ id: "clock", x: 0.2, y: 0.2,
                                font: "DejaVu Sans", weight: "bold", italic: true }]
                }
            }
        })
        var placed = Layouts.effective(text, "DP-1", null, "desktop").widgets
        compare(placed.length, 1)
        var host = createTemporaryObject(clockHost, testCase, {
            fontFamily: placed[0].font,
            fontWeight: placed[0].weight,
            italic: placed[0].italic
        })
        var time = findChild(host, "dashboardClock")
        compare(time.font.family, "DejaVu Sans")
        compare(time.font.weight, Font.Bold)
        compare(time.font.italic, true)
    }
}
