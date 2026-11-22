"""Market prices, keyless: CoinGecko's public `/coins/markets` endpoint.

    python3 -m vitrail.market state <coin-id>... [--currency <code>]

PRIVACY: this module makes an outbound request. It sends CoinGecko the coin ids
and the currency you asked for, and nothing else: no account, no e-mail, no API
key, no identifier of any kind. You chose this provider by enabling the market
element. There is no API key path here on purpose; if CoinGecko ever requires
one, this module stops instead of growing one.

The answer is cached in ~/.cache/vitrail/market.json for 5 minutes, one request
per refresh whatever the number of symbols. Without a network the last answer
comes back with `error`; with no cache at all the state keeps its shape with an
empty `prices` list.
"""

from __future__ import annotations

import http.client
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from collections.abc import Callable, Iterable
from pathlib import Path

MARKETS = "https://api.coingecko.com/api/v3/coins/markets"
CACHE_FILE = "market.json"
CACHE_SECONDS = 5 * 60
TIMEOUT = 8
MAX_BYTES = 1024 * 1024
DEFAULT_CURRENCY = "usd"
# The currencies the bar's popup offers, in the chooser's order. `state` still
# accepts any CoinGecko code; these are only the ones the element names.
CURRENCIES = ("eur", "usd")
CHANGE = "24h"

Fetcher = Callable[[str], str]


def cache_file(folder: Path | None = None) -> Path:
    """The cache file, under ~/.cache/vitrail unless a folder is given."""
    base = folder or Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / "vitrail"
    return base / CACHE_FILE


def http_get(url: str) -> str:
    """The body of a URL; OSError when it cannot be reached."""
    request = urllib.request.Request(url, headers={"User-Agent": "vitrail"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as answer:
            return answer.read(MAX_BYTES).decode("utf-8", "replace")
    except http.client.HTTPException as error:
        raise OSError(str(error)) from error


def markets_url(ids: Iterable[str], currency: str) -> str:
    """One request for every symbol, with the ids sorted so the URL is stable."""
    query = {
        "vs_currency": str(currency).lower(),
        "ids": ",".join(sorted(set(ids))),
        "sparkline": "true",
        "price_change_percentage": CHANGE,
    }
    return f"{MARKETS}?{urllib.parse.urlencode(query)}"


def _number(value: object, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"missing {field}")
    return float(value)


def _text(value: object, field: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"missing {field}")
    return value.strip()


def _sparkline(coin: dict) -> list[float] | None:
    series = coin.get("sparkline_in_7d")
    prices = series.get("price") if isinstance(series, dict) else None
    if not isinstance(prices, list):
        return None
    return [_number(one, "sparkline price") for one in prices]


def parse_markets(text: str) -> list[dict]:
    """CoinGecko's answer as the flat list the bar and the popup show.

    A ValueError when the answer is not the document the request asked for,
    which is how a captive portal, a rate limit page or a changed API is
    reported.
    """
    try:
        data = json.loads(text)
    except ValueError as error:
        raise ValueError("the market answer is not JSON") from error
    if not isinstance(data, list):
        raise ValueError("the market answer is not a list")
    if not data:
        raise ValueError("the market answer is empty")
    prices = []
    for coin in data:
        if not isinstance(coin, dict):
            raise ValueError("the market answer has a malformed coin")
        prices.append(
            {
                "id": _text(coin.get("id"), "coin id"),
                "symbol": _text(coin.get("symbol"), "symbol"),
                "name": _text(coin.get("name"), "name"),
                "price": _number(coin.get("current_price"), "current price"),
                "change24h": _number(coin.get("price_change_24h"), "24h change"),
                "change24hPercent": _number(coin.get("price_change_percentage_24h"), "24h change percentage"),
                "sparkline": _sparkline(coin),
            }
        )
    return prices


def load_cache(path: Path) -> dict | None:
    try:
        stored = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None
    return stored if isinstance(stored, dict) else None


def save_cache(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    partial = path.with_name(f".{path.name}.part")
    partial.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
    os.replace(partial, path)


def _normalise(symbols: Iterable[str]) -> list[str]:
    return sorted({str(one).strip().lower() for one in symbols if str(one).strip()})


def _matches(stored: dict | None, ids: list[str], currency: str) -> bool:
    """Whether a stored answer is about this request, whatever its age."""
    return bool(
        stored
        and isinstance(stored.get("state"), dict)
        and stored.get("currency") == currency
        and stored.get("symbols") == ids
    )


def _fresh(stored: dict | None, ids: list[str], currency: str, now: float) -> bool:
    if not _matches(stored, ids, currency):
        return False
    saved = stored.get("saved_at")
    return isinstance(saved, (int, float)) and 0 <= now - saved < CACHE_SECONDS


def state(
    symbols: Iterable[str],
    currency: str = DEFAULT_CURRENCY,
    cache: Path | None = None,
    get: Fetcher = http_get,
    now: float | None = None,
) -> dict:
    """The prices for `symbols` (CoinGecko ids) in `currency`.

    `currency`, `prices` and `fetchedAt` (epoch seconds), plus `cached` for
    whether it came from disk. One request covers every symbol; a fresh cache
    answers without the network, and an expired one answers when the network
    fails, with `error` saying why.
    """
    ids = _normalise(symbols)
    code = str(currency).strip().lower() or DEFAULT_CURRENCY
    path = cache_file(cache)
    stored = load_cache(path)
    now = time.time() if now is None else now
    empty = {"currency": code, "prices": [], "fetchedAt": None, "cached": False}

    if not ids:
        return {**empty, "error": "no symbols requested"}
    if _fresh(stored, ids, code, now):
        return {**stored["state"], "cached": True}

    try:
        result = {"currency": code, "prices": parse_markets(get(markets_url(ids, code))), "fetchedAt": int(now)}
        save_cache(path, {"saved_at": now, "currency": code, "symbols": ids, "state": result})
        return {**result, "cached": False}
    except (OSError, ValueError, http.client.HTTPException) as error:
        if _matches(stored, ids, code):
            return {**stored["state"], "cached": True, "error": str(error)}
        return {**empty, "error": str(error)}


def main(argv: list[str] | None = None) -> int:
    args = list(sys.argv[1:] if argv is None else argv)
    currency = DEFAULT_CURRENCY
    if "--currency" in args:
        index = args.index("--currency")
        if index + 1 >= len(args):
            print("usage: market state <coin-id>... [--currency <code>]", file=sys.stderr)
            return 2
        currency = args[index + 1]
        del args[index : index + 2]
    if not args or args[0] != "state" or len(args) < 2:
        print("usage: market state <coin-id>... [--currency <code>]", file=sys.stderr)
        return 2
    data = state(args[1:], currency)
    print(json.dumps(data, separators=(",", ":")))
    return 0 if data["prices"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
