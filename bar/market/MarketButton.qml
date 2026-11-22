import QtQuick
import ".."
import "../kit"
import "market.js" as Market

// The market bar element: the chosen symbol's price with the day's trend as
// the icon's glyph and tone, from vitrail.market's snapshot (BarSnapshot).
// "Only while active" is its default mode (bar/elements.js): a price element
// with no price has nothing to put in the slot, and the module's cache keeps
// the last price on screen through a network failure; a cold cache with no
// network is the one case where it leaves the bar. "always" keeps the glyph in
// place for anyone who wants the slot steady.
BarElementBase {
    id: root

    // The element's data: vitrail.market's snapshot.
    property var snapshot: ({})
    // The `marketSymbols` preference (one JSON array of CoinGecko ids).
    property string symbols: ""
    // The `marketCurrency` preference (a code from market.js' list).
    property string currency: "eur"
    // The clock behind "updated X ago"; the timer below moves it.
    property double now: Date.now()

    readonly property var primary: Market.priceFor(root.snapshot, root.symbols)
    readonly property var prices: Market.priceList(root.snapshot)
    readonly property string failure: Market.errorOf(root.snapshot)
    readonly property int chosen: Market.symbolsOf(root.symbols).length

    icon: root.primary ? Market.arrow(root.primary.change24hPercent) : "monitoring"
    text: root.primary ? Market.formatPrice(root.primary.price, root.currency) : ""
    tone: root.primary ? Market.tone(root.primary.change24hPercent) : "secondary"
    showMode: "active"
    active: root.prices.length > 0
    tooltip: root.primary ? Market.summary(root.primary) : root.t("bar.market.empty")
    tooltipDetail: {
        if (root.chosen === 0)
            return root.t("bar.market.noSymbols")
        if (root.failure !== "")
            return root.failure
        if (!root.primary)
            return root.t("bar.market.unavailable")
        var rest = Market.restSummary(root.snapshot, root.symbols)
        return rest !== "" ? rest : Market.updatedText(root.snapshot.fetchedAt, root.snapshot.cached,
                                                      root.now, root.strings)
    }

    Timer {
        interval: VitrailTokens.motion.minute
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }
}
