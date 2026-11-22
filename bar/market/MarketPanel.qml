import QtQuick
import QtQuick.Layouts
import "../kit"
import "../kit/base"
import "market.js" as Market

// The market element's popup: one row per chosen symbol with its name, its
// price, the day's change (arrow, percentage and colour by sign) and the
// sparkline from the snapshot; a currency chooser; the refresh button with the
// age of the data; the CoinGecko line in small print; and a calm line for an
// error. The gear opens the element's block in Settings → Bar elements.
Item {
    id: root

    property var strings: ({})
    property var snapshot: ({})
    // The `marketSymbols` preference (one JSON array of CoinGecko ids).
    property string symbols: ""
    // The `marketCurrency` preference (a code from market.js' list).
    property string currency: "eur"
    // The clock behind "updated X ago"; the timer below moves it.
    property double now: Date.now()

    signal settingsRequested()
    signal currencyRequested(string code)
    signal refreshRequested()

    readonly property var chosen: Market.symbolsOf(root.symbols)
    readonly property var list: Market.rows(root.snapshot, root.symbols)
    readonly property string failure: Market.errorOf(root.snapshot)
    readonly property string updated: Market.updatedText(root.snapshot.fetchedAt,
                                                        root.snapshot.cached,
                                                        root.now, root.strings)
    // About six rows fit before the list starts to scroll.
    readonly property real listMax: VitrailTokens.size("display") * 6

    function t(key) {
        var value = root.strings[key]
        return value === undefined ? key : value
    }

    onVisibleChanged: if (root.visible) root.now = Date.now()

    implicitWidth: 400
    implicitHeight: body.implicitHeight

    Timer {
        interval: VitrailTokens.motion.minute
        repeat: true
        running: root.visible
        onTriggered: root.now = Date.now()
    }

    ColumnLayout {
        id: body

        anchors.fill: parent
        spacing: VitrailTokens.gap("md")

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                Layout.fillWidth: true
                variant: "subtitle"
                elide: Text.ElideRight
                text: root.t("bar.widget.market")
            }

            VitrailText {
                objectName: "updated"

                Layout.alignment: Qt.AlignVCenter
                variant: "label"
                elide: Text.ElideRight
                text: root.updated
            }

            VitrailButton {
                objectName: "refresh"

                variant: "plain"
                tone: "secondary"
                size: "sm"
                icon: "refresh"
                enabled: root.chosen.length > 0
                onClicked: root.refreshRequested()
            }

            VitrailPopupGear {
                Layout.alignment: Qt.AlignTop
                onClicked: root.settingsRequested()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: VitrailTokens.gap("sm")

            VitrailText {
                variant: "label"
                text: root.t("bar.market.currency")
            }

            Item { Layout.fillWidth: true }

            VitrailSegmented {
                objectName: "currency"

                options: Market.currencyOptions()
                current: Market.currencyOf(root.currency)
                foreground: VitrailTokens.color("foreground")
                accent: VitrailTokens.color("primary")
                onSelected: function (key) { root.currencyRequested(key) }
            }
        }

        VitrailText {
            objectName: "error"

            Layout.fillWidth: true
            visible: root.failure !== "" && root.chosen.length > 0
            variant: "label"
            wrapMode: Text.WordWrap
            text: root.t("bar.market.error").replace("%1", root.failure)
        }

        VitrailText {
            objectName: "noSymbols"

            Layout.fillWidth: true
            visible: root.chosen.length === 0
            variant: "body"
            wrapMode: Text.WordWrap
            text: root.t("bar.market.noSymbols")
        }

        Flickable {
            id: scroller

            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(rows.implicitHeight, root.listMax)
            visible: root.list.length > 0
            contentWidth: width
            contentHeight: rows.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            ColumnLayout {
                id: rows

                width: scroller.width
                spacing: VitrailTokens.gap("md")

                Repeater {
                    model: root.list

                    delegate: RowLayout {
                        id: priceRow

                        required property var modelData

                        readonly property var price: priceRow.modelData.price

                        objectName: "priceRow"

                        Layout.fillWidth: true
                        spacing: VitrailTokens.gap("md")

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: VitrailTokens.gap("xs")

                            VitrailText {
                                Layout.fillWidth: true
                                variant: "body"
                                elide: Text.ElideRight
                                text: Market.rowTitle(priceRow.modelData)
                            }

                            VitrailText {
                                Layout.fillWidth: true
                                visible: text !== ""
                                variant: "label"
                                opacity: 0.7
                                elide: Text.ElideRight
                                text: Market.symbolOf(priceRow.price)
                            }
                        }

                        MarketSparkline {
                            Layout.preferredWidth: VitrailTokens.size("display") * 3
                            Layout.preferredHeight: VitrailTokens.size("title")
                            values: priceRow.price && Array.isArray(priceRow.price.sparkline)
                                    ? priceRow.price.sparkline : []
                            tone: priceRow.price ? Market.colorToken(priceRow.price.change24hPercent) : "muted"
                        }

                        ColumnLayout {
                            spacing: VitrailTokens.gap("xs")

                            VitrailText {
                                Layout.alignment: Qt.AlignRight
                                variant: "body"
                                font.weight: Font.DemiBold
                                text: priceRow.price
                                      ? Market.formatPrice(priceRow.price.price, root.currency) : "—"
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignRight
                                spacing: VitrailTokens.gap("xs")

                                VitrailIcon {
                                    icon: priceRow.price ? Market.arrow(priceRow.price.change24hPercent) : "remove"
                                    tone: priceRow.price ? Market.colorToken(priceRow.price.change24hPercent) : "muted"
                                    size: "sm"
                                    container: false
                                }

                                VitrailText {
                                    objectName: priceRow.price ? "change" : "notFound"

                                    variant: "label"
                                    color: VitrailTokens.color(priceRow.price
                                                               ? Market.colorToken(priceRow.price.change24hPercent)
                                                               : "muted")
                                    text: priceRow.price
                                          ? Market.changeText(priceRow.price.change24hPercent)
                                          : root.t("bar.market.notFound")
                                }
                            }
                        }
                    }
                }
            }
        }

        VitrailText {
            objectName: "source"

            Layout.fillWidth: true
            variant: "label"
            opacity: 0.7
            wrapMode: Text.WordWrap
            text: root.t("bar.market.source")
        }
    }
}
