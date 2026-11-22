import QtQuick
import QtTest
import "../../bar/kit"
import "../../bar/market"
import "../../bar/market/market.js" as Market

// The market element: the price formatting, the day's change (its arrow, its
// sign and its tone), the age of the data, the symbol list, and the button and
// panel built on them. market.js is plain logic, so the fixtures are plain
// objects.
TestCase {
    id: testCase

    name: "Market"
    when: windowShown
    visible: true
    width: 460
    height: 720

    readonly property var strings: ({
        "bar.widget.market": "Markets",
        "bar.market.empty": "No market data",
        "bar.market.unavailable": "Prices unavailable",
        "bar.market.currency": "Currency",
        "bar.market.updated": "updated %1",
        "bar.market.justNow": "just now",
        "bar.market.minutes": "%1 min ago",
        "bar.market.hours": "%1 h ago",
        "bar.market.days": "%1 d ago",
        "bar.market.cached": "cached",
        "bar.market.source": "Prices from CoinGecko over the internet.",
        "bar.market.error": "Could not update the prices (%1).",
        "bar.market.notFound": "No price",
        "bar.market.noSymbols": "No symbols chosen."
    })

    readonly property var bitcoin: ({
        id: "bitcoin", symbol: "btc", name: "Bitcoin", price: 78420.1,
        change24h: 1060.2, change24hPercent: 1.37,
        sparkline: [77400.0, 77800.0, 78100.0, 78420.1]
    })

    readonly property var ethereum: ({
        id: "ethereum", symbol: "eth", name: "Ethereum", price: 2589.3,
        change24h: -39.1, change24hPercent: -1.49,
        sparkline: [2660.0, 2620.0, 2600.0, 2589.3]
    })

    readonly property var snapshot: ({
        currency: "eur", prices: [bitcoin, ethereum],
        fetchedAt: 1000000, cached: false
    })

    Component {
        id: buttonComponent

        MarketButton {
            width: 60
            height: 40
            strings: testCase.strings
            symbols: '["bitcoin","ethereum"]'
            currency: "eur"
        }
    }

    Component {
        id: panelComponent

        MarketPanel {
            width: 400
            strings: testCase.strings
            symbols: '["bitcoin","ethereum"]'
            currency: "eur"
        }
    }

    VitrailPalette {
        id: palette
    }

    SignalSpy { id: currencySpy; signalName: "currencyRequested" }
    SignalSpy { id: refreshSpy; signalName: "refreshRequested" }
    SignalSpy { id: settingsSpy; signalName: "settingsRequested" }

    function initTestCase() {
        VitrailTokens.configure(palette, true, "glass", ({}))
    }

    function make(component) {
        var item = createTemporaryObject(component, testCase)
        verify(item !== null)
        return item
    }

    function descendants(item, name, found) {
        var out = found || []
        for (var i = 0; i < item.children.length; i++) {
            var child = item.children[i]
            if (child.objectName === name)
                out.push(child)
            descendants(child, name, out)
        }
        return out
    }

    // --- market.js -----------------------------------------------------------

    function test_the_price_carries_the_currency_and_grouped_digits() {
        compare(Market.formatPrice(78420.1, "eur"), "€78,420.10")
        compare(Market.formatPrice(3012.25, "usd"), "$3,012.25")
        compare(Market.formatPrice(0.0000123, "usd"), "$0.000012")
        compare(Market.formatPrice(0, "eur"), "€0.00")
        compare(Market.formatPrice(null, "eur"), "—")
        compare(Market.currencyOf("USD"), "usd")
        compare(Market.currencyOf("yen"), "eur")
        compare(Market.currencyOptions().map(function (one) { return one.key }), ["eur", "usd"])
    }

    function test_the_day_change_has_a_sign_a_tone_and_an_arrow() {
        compare(Market.changeText(1.37), "+1.37%")
        compare(Market.changeText(-1.49), "-1.49%")
        compare(Market.changeText(0), "0.00%")
        compare(Market.changeText(null), "—")

        compare(Market.trend(1.37), "up")
        compare(Market.trend(-1.49), "down")
        compare(Market.trend(0), "flat")
        compare(Market.arrow(1.37), "arrow_upward")
        compare(Market.arrow(-1.49), "arrow_downward")
        compare(Market.arrow(0), "remove")
        compare(Market.tone(1.37), "primary")
        compare(Market.tone(-1.49), "error")
        compare(Market.tone(0), "secondary")
        compare(Market.colorToken(1.37), "primary")
        compare(Market.colorToken(-1.49), "error")
        compare(Market.colorToken(0), "muted")
    }

    function test_the_age_says_updated_and_marks_a_cached_answer() {
        var now = (1000000 + 180) * 1000
        compare(Market.updatedText(1000000, false, now, testCase.strings), "updated 3 min ago")
        compare(Market.updatedText(1000000, true, now, testCase.strings), "cached · updated 3 min ago")
        compare(Market.updatedText(now / 1000 - 20, false, now, testCase.strings), "updated just now")
        compare(Market.updatedText(now / 1000 - 7200, false, now, testCase.strings), "updated 2 h ago")
        compare(Market.updatedText(null, false, now, testCase.strings), "")
    }

    function test_the_symbol_list_is_a_json_array_of_coin_gecko_ids() {
        compare(Market.symbolsOf('["Bitcoin","ethereum","bitcoin",""]'), ["bitcoin", "ethereum"])
        compare(Market.symbolsOf("[]"), [])
        compare(Market.symbolsOf("not json"), ["bitcoin"])
        compare(Market.symbolsOf(undefined), ["bitcoin"])
        compare(Market.normalizeSymbol("  USD-Coin "), "usd-coin")
        compare(Market.normalizeSymbol("not a coin"), "")
        compare(Market.withSymbol('["bitcoin"]', "Ethereum", true), '["bitcoin","ethereum"]')
        compare(Market.withSymbol('["bitcoin","ethereum"]', "bitcoin", false), '["ethereum"]')
    }

    function test_the_interval_never_goes_below_the_cache_floor() {
        compare(Market.intervalMinutes(2), 5)
        compare(Market.intervalMinutes(15), 15)
        compare(Market.intervalMinutes("nope"), 15)
        compare(Market.intervalMs(15), 900000)
        compare(Market.commandArguments('["bitcoin","ethereum"]', "usd"),
                ["bitcoin", "ethereum", "--currency", "usd"])
    }

    function test_rows_keep_the_configured_order_and_show_a_missing_symbol() {
        var rows = Market.rows(snapshot, '["ethereum","bitcoin","dogecoin"]')
        compare(rows.length, 3)
        compare(rows[0].id, "ethereum")
        compare(rows[0].price.name, "Ethereum")
        compare(rows[1].price.name, "Bitcoin")
        compare(rows[2].price, null)
        compare(Market.priceFor(snapshot, '["ethereum","bitcoin"]').id, "ethereum")
        compare(Market.priceFor(snapshot, '["dogecoin","bitcoin"]').id, "bitcoin")
        compare(Market.restSummary(snapshot, '["bitcoin"]'), "ETH -1.49%")
    }

    // --- the button ----------------------------------------------------------

    function test_the_button_shows_the_chosen_price_and_its_trend() {
        var button = make(buttonComponent)
        button.snapshot = snapshot
        compare(button.text, "€78,420.10")
        compare(button.icon, "arrow_upward")
        compare(button.tone, "primary")
        compare(button.active, true)
        compare(button.showMode, "active")
        compare(button.tooltip, "BTC +1.37%")
        compare(button.tooltipDetail, "ETH -1.49%")

        button.snapshot = { currency: "eur", prices: [ethereum], fetchedAt: 1000000 }
        compare(button.text, "€2,589.30")
        compare(button.icon, "arrow_downward")
        compare(button.tone, "error")
    }

    function test_the_button_keeps_a_warm_cache_and_reports_the_error() {
        var button = make(buttonComponent)
        button.snapshot = { currency: "eur", prices: [bitcoin], fetchedAt: 1000000,
                            cached: true, error: "offline" }
        compare(button.active, true)
        compare(button.text, "€78,420.10")
        compare(button.tooltipDetail, "offline")

        button.snapshot = { error: "unreadable" }
        compare(button.active, false)
        compare(button.tooltip, "No market data")
        compare(button.tooltipDetail, "unreadable")
    }

    // --- the panel -----------------------------------------------------------

    function test_the_panel_draws_one_row_per_symbol_with_a_sparkline() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot
        panel.now = (1000000 + 180) * 1000
        compare(descendants(panel, "priceRow").length, 2)
        compare(descendants(panel, "sparkline").length, 2)

        var changes = descendants(panel, "change")
        compare(changes.length, 2)
        compare(changes[0].text, "+1.37%")
        compare(changes[0].color, VitrailTokens.color("primary"))
        compare(changes[1].text, "-1.49%")
        compare(changes[1].color, VitrailTokens.color("error"))
        compare(descendants(panel, "updated")[0].text, "updated 3 min ago")
        compare(descendants(panel, "source")[0].text, "Prices from CoinGecko over the internet.")
    }

    function test_the_panel_asks_for_a_currency_a_refresh_and_settings() {
        var panel = make(panelComponent)
        panel.snapshot = snapshot

        var currency = descendants(panel, "currency")[0]
        verify(currency !== null)
        currencySpy.target = panel
        currencySpy.clear()
        currency.selected("usd")
        compare(currencySpy.count, 1)
        compare(currencySpy.signalArguments[0][0], "usd")

        refreshSpy.target = panel
        refreshSpy.clear()
        mouseClick(descendants(panel, "refresh")[0], 5, 5)
        compare(refreshSpy.count, 1)

        settingsSpy.target = panel
        settingsSpy.clear()
        var gear = findChild(panel, "popupSettings")
        verify(gear !== null)
        mouseClick(gear, gear.width / 2, gear.height / 2)
        compare(settingsSpy.count, 1)
    }

    function test_the_panel_says_an_error_and_a_missing_symbol_calmly() {
        var panel = make(panelComponent)
        panel.snapshot = { currency: "eur", prices: [], fetchedAt: null, error: "offline" }
        compare(descendants(panel, "error")[0].text, "Could not update the prices (offline).")
        var rows = descendants(panel, "priceRow")
        compare(rows.length, 2)
        compare(descendants(panel, "notFound").length, 2)

        panel.symbols = "[]"
        panel.snapshot = { currency: "eur", prices: [], fetchedAt: null }
        compare(descendants(panel, "noSymbols")[0].visible, true)
    }
}
