"""The market service: keyless CoinGecko, one request per refresh, and a cache
that keeps the last answer when the network is gone.

Every request is answered by a fake `get`, so these tests never touch the
network or the clock.
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from vitrail import market

MARKETS = json.dumps(
    [
        {
            "id": "bitcoin",
            "symbol": "btc",
            "name": "Bitcoin",
            "current_price": 91234.5,
            "market_cap": 1800000000000,
            "price_change_24h": 1234.5,
            "price_change_percentage_24h": 1.37,
            "sparkline_in_7d": {"price": [90000.0, 90500.5, 91234.5]},
        },
        {
            "id": "ethereum",
            "symbol": "eth",
            "name": "Ethereum",
            "current_price": 3012.25,
            "market_cap": 360000000000,
            "price_change_24h": -45.5,
            "price_change_percentage_24h": -1.49,
            "sparkline_in_7d": {"price": [3100.0, 3050.0, 3012.25]},
        },
    ]
)
EUR = json.dumps(
    [
        {
            "id": "bitcoin",
            "symbol": "btc",
            "name": "Bitcoin",
            "current_price": 78420.1,
            "price_change_24h": 1060.2,
            "price_change_percentage_24h": 1.37,
            "sparkline_in_7d": {"price": [77400.0, 77800.0, 78420.1]},
        },
        {
            "id": "ethereum",
            "symbol": "eth",
            "name": "Ethereum",
            "current_price": 2589.3,
            "price_change_24h": -39.1,
            "price_change_percentage_24h": -1.49,
            "sparkline_in_7d": {"price": [2660.0, 2620.0, 2589.3]},
        },
    ]
)


class Fake:
    """Answers with one body and remembers what was asked."""

    def __init__(self, body: str | Exception = MARKETS) -> None:
        self.body = body
        self.calls: list[str] = []

    def __call__(self, url: str) -> str:
        self.calls.append(url)
        if isinstance(self.body, Exception):
            raise self.body
        return self.body


class ParseTests(unittest.TestCase):
    def test_the_answer_becomes_the_flat_shape_the_bar_shows(self) -> None:
        prices = market.parse_markets(MARKETS)
        self.assertEqual(
            prices,
            [
                {
                    "id": "bitcoin",
                    "symbol": "btc",
                    "name": "Bitcoin",
                    "price": 91234.5,
                    "change24h": 1234.5,
                    "change24hPercent": 1.37,
                    "sparkline": [90000.0, 90500.5, 91234.5],
                },
                {
                    "id": "ethereum",
                    "symbol": "eth",
                    "name": "Ethereum",
                    "price": 3012.25,
                    "change24h": -45.5,
                    "change24hPercent": -1.49,
                    "sparkline": [3100.0, 3050.0, 3012.25],
                },
            ],
        )
        self.assertIsInstance(prices[0]["sparkline"][0], float)

    def test_a_coin_without_a_sparkline_gets_null(self) -> None:
        body = json.loads(MARKETS)
        del body[0]["sparkline_in_7d"]
        self.assertIsNone(market.parse_markets(json.dumps(body))[0]["sparkline"])
        for empty in ({}, {"price": None}, {"price": "x"}):
            with self.subTest(sparkline=empty):
                body[0]["sparkline_in_7d"] = empty
                self.assertIsNone(market.parse_markets(json.dumps(body))[0]["sparkline"])

    def test_a_malformed_answer_is_refused(self) -> None:
        for body in (
            "not json",
            "{}",
            json.dumps([1]),
            json.dumps([{"id": "bitcoin", "symbol": "btc", "name": "Bitcoin"}]),
            json.dumps([{"id": "bitcoin", "symbol": "btc", "name": "Bitcoin", "current_price": "x"}]),
            json.dumps(
                [
                    {
                        "id": "bitcoin",
                        "symbol": "btc",
                        "name": "Bitcoin",
                        "current_price": 1.0,
                        "price_change_24h": 1.0,
                        "price_change_percentage_24h": None,
                    }
                ]
            ),
        ):
            with self.subTest(body=body), self.assertRaises(ValueError):
                market.parse_markets(body)

    def test_an_empty_answer_is_an_error(self) -> None:
        with self.assertRaises(ValueError):
            market.parse_markets("[]")

    def test_the_url_carries_the_sorted_ids_currency_and_sparkline(self) -> None:
        url = market.markets_url(["ethereum", "bitcoin"], "EUR")
        self.assertTrue(url.startswith("https://api.coingecko.com/api/v3/coins/markets?"))
        for part in (
            "vs_currency=eur",
            "ids=bitcoin%2Cethereum",
            "sparkline=true",
            "price_change_percentage=24h",
        ):
            self.assertIn(part, url)


class Fixture(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.cache = self.root / "cache" / "vitrail"
        self.cache.mkdir(parents=True)

    def state(
        self,
        fake: Fake,
        symbols: tuple[str, ...] = ("bitcoin", "ethereum"),
        currency: str = "usd",
        now: float = 1_000_000.0,
    ) -> dict:
        return market.state(symbols, currency, self.cache, fake, now)


class StateTests(Fixture):
    def test_the_first_state_is_fetched_in_one_request_and_cached(self) -> None:
        fake = Fake()
        data = self.state(fake)
        self.assertEqual(data["currency"], "usd")
        self.assertEqual([one["id"] for one in data["prices"]], ["bitcoin", "ethereum"])
        self.assertEqual(data["fetchedAt"], 1_000_000)
        self.assertFalse(data["cached"])
        self.assertNotIn("error", data)
        self.assertEqual(len(fake.calls), 1)
        self.assertIn("api.coingecko.com/api/v3/coins/markets", fake.calls[0])
        self.assertTrue((self.cache / market.CACHE_FILE).is_file())

    def test_a_fresh_cache_answers_without_the_network(self) -> None:
        self.state(Fake())
        fake = Fake()
        data = self.state(fake, now=1_000_000.0 + market.CACHE_SECONDS - 1)
        self.assertTrue(data["cached"])
        self.assertEqual(fake.calls, [])
        self.assertEqual(data["prices"][0]["price"], 91234.5)

    def test_an_expired_cache_is_fetched_again(self) -> None:
        self.state(Fake())
        fake = Fake()
        data = self.state(fake, now=1_000_000.0 + market.CACHE_SECONDS + 1)
        self.assertEqual(len(fake.calls), 1)
        self.assertFalse(data["cached"])

    def test_the_same_symbols_in_another_order_hit_the_cache(self) -> None:
        self.state(Fake())
        fake = Fake()
        data = self.state(fake, symbols=("ethereum", "bitcoin", "bitcoin"))
        self.assertTrue(data["cached"])
        self.assertEqual(fake.calls, [])

    def test_without_a_network_the_last_answer_comes_back_with_an_error(self) -> None:
        self.state(Fake())
        data = self.state(Fake(OSError("offline")), now=1_000_000.0 + market.CACHE_SECONDS + 1)
        self.assertTrue(data["cached"])
        self.assertIn("offline", data["error"])
        self.assertEqual(data["prices"][0]["price"], 91234.5)

    def test_without_a_network_or_a_cache_the_state_keeps_its_shape(self) -> None:
        data = self.state(Fake(OSError("offline")))
        self.assertEqual(data["currency"], "usd")
        self.assertEqual(data["prices"], [])
        self.assertIsNone(data["fetchedAt"])
        self.assertFalse(data["cached"])
        self.assertIn("offline", data["error"])

    def test_an_invalid_answer_is_an_error_not_a_crash(self) -> None:
        data = self.state(Fake("{broken"))
        self.assertEqual(data["prices"], [])
        self.assertIn("error", data)
        self.assertFalse((self.cache / market.CACHE_FILE).exists())

    def test_another_currency_is_fetched_instead_of_reusing_the_cache(self) -> None:
        self.state(Fake())
        fake = Fake(EUR)
        data = self.state(fake, currency="eur", now=1_000_000.0 + 1)
        self.assertFalse(data["cached"])
        self.assertEqual(len(fake.calls), 1)
        self.assertIn("vs_currency=eur", fake.calls[0])
        self.assertEqual(data["prices"][0]["price"], 78420.1)

    def test_a_cache_in_another_currency_is_not_served_offline(self) -> None:
        self.state(Fake())
        data = self.state(Fake(OSError("offline")), currency="eur", now=1_000_000.0 + market.CACHE_SECONDS + 1)
        self.assertIn("offline", data["error"])
        self.assertEqual(data["prices"], [])

    def test_no_symbols_makes_no_request(self) -> None:
        fake = Fake()
        data = self.state(fake, symbols=())
        self.assertEqual(fake.calls, [])
        self.assertEqual(data["prices"], [])
        self.assertIn("error", data)

    def test_the_cache_holds_only_the_flat_state(self) -> None:
        self.state(Fake())
        stored = json.loads((self.cache / market.CACHE_FILE).read_text(encoding="utf-8"))
        self.assertEqual(stored["currency"], "usd")
        self.assertEqual(stored["symbols"], ["bitcoin", "ethereum"])
        self.assertEqual(set(stored["state"]), {"currency", "prices", "fetchedAt"})


if __name__ == "__main__":
    unittest.main()
