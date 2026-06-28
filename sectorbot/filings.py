"""NSE/BSE corporate-filings reader for the Swaminatha face.

Swaminatha (Mayura's "Guru") only paper-buys a stock when its RECENT corporate
filing reads BULLISH, and never buys into a clear red-flag (SEBI action, default,
auditor resignation, pledge invocation, etc.).

Two independent parts, so each is easy to test and swap:
  1. FETCH   -> pull recent announcements for an NSE symbol (free, no API key).
  2. CLASSIFY-> rule/keyword sentiment on the announcement text (bullish /
                bearish / neutral). Free and deterministic. An LLM judge could
                later be slotted in for the "neutral/gray" cases — see
                assess_symbol() — but that is intentionally NOT wired here.

Design choices:
  * FAIL-SAFE for buying: if we can't fetch (NSE blocks the host, network down),
    the verdict is "unknown" and Swaminatha does NOT buy. No news != good news.
  * Network code is fully isolated in _fetch_nse so the classifier can be unit
    tested offline.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timedelta

from . import config


@dataclass
class Announcement:
    symbol: str
    date: str        # ISO date string (best-effort)
    subject: str     # short headline / category
    detail: str = "" # longer body text if present

    @property
    def text(self) -> str:
        return f"{self.subject} {self.detail}".lower()


# --- Keyword sentiment ------------------------------------------------------
# Weights are rough "how strong a signal" scores. Phrases are matched as plain
# substrings against the lower-cased announcement text. Keep them specific to
# avoid false hits (e.g. "order" alone is too generic; "bags order" is not).
BULLISH: dict[str, float] = {
    "bags order": 3, "bags an order": 3, "receives order": 3, "secured order": 3,
    "secures order": 3, "wins order": 3, "won order": 3, "order worth": 3,
    "order win": 3, "orders worth": 3, "bags orders": 3, "secures orders": 3,
    "receives orders": 3, "wins orders": 3, "secured orders": 3, "new orders": 2,
    "order inflow": 2, "order book": 1, "bags a contract": 3,
    "new order": 2, "work order": 2, "letter of intent": 2, "letter of award": 3,
    "awarded contract": 3, "awarded a contract": 3, "contract worth": 3,
    "bags contract": 3, "purchase order": 2,
    "record date": 1, "bonus issue": 2, "buyback": 3, "buy-back": 3,
    "stock split": 1, "interim dividend": 1, "final dividend": 1,
    "highest ever": 3, "record revenue": 3, "record profit": 3,
    "record sales": 2, "net profit rose": 3, "profit jumps": 3,
    "profit up": 2, "profit doubled": 3, "robust growth": 2, "strong growth": 2,
    "capacity expansion": 2, "capacity addition": 2, "new plant": 2,
    "commissioning": 2, "commissioned": 2, "greenfield": 2, "capex": 1,
    "expansion plan": 2, "ramp up": 1,
    "acquisition": 1, "acquires": 1, "to acquire": 1, "strategic partnership": 2,
    "joint venture": 1, "mou": 1, "memorandum of understanding": 1,
    "usfda": 3, "us fda": 3, "fda approval": 3, "drug approval": 3,
    "establishment inspection report": 2, "eir": 2, "regulatory approval": 2,
    "approval received": 2, "patent granted": 2, "patent granted": 2,
    "rating upgrade": 3, "rating upgraded": 3, "upgraded its rating": 3,
    "upgrades long-term rating": 3, "upgrades rating": 3, "upgrades its rating": 3,
    "rating upgraded to": 3, "ratings upgraded": 3, "revises rating upward": 3,
    "credit rating upgrade": 3,
    "outlook revised to positive": 3, "outlook: positive": 2,
    "increase in promoter": 2, "promoter acquired": 3, "promoter buying": 3,
    "preferential allotment to promoter": 2,
    "qip": 1, "fund raising": 1, "fundraising": 1,
}

BEARISH: dict[str, float] = {
    "resignation of auditor": 5, "auditor resigned": 5, "auditor resignation": 5,
    "resignation of cfo": 4, "resignation of chief financial": 4,
    "resignation of managing director": 4, "resignation of ceo": 4,
    "resignation of company secretary": 2, "resigns": 2, "stepped down": 2,
    "qualified opinion": 4, "adverse opinion": 5, "going concern": 5,
    "disclaimer of opinion": 5, "audit qualification": 4,
    "sebi": 4, "show cause notice": 4, "show-cause notice": 4,
    "penalty imposed": 4, "penalty of": 3, "fine imposed": 3, "prosecution": 4,
    "investigation": 3, "search and seizure": 5, "income tax raid": 5,
    "income tax search": 5, "ed summons": 5, "enforcement directorate": 5,
    "cbi": 4, "fir against": 4, "fraud": 5, "forensic audit": 4,
    "default": 4, "defaulted": 4, "nclt": 4, "insolvency": 5, "ibc": 3,
    "cirp": 5, "winding up": 5, "liquidation": 5, "moratorium": 3,
    "rating downgrade": 4, "rating downgraded": 4, "downgraded": 3,
    "downgrades rating": 4, "downgrades long-term rating": 4,
    "rating downgraded to": 4, "revises rating downward": 4,
    "outlook revised to negative": 4, "rating withdrawn": 3,
    "pledge": 2, "invocation of pledge": 5, "pledged shares": 2,
    "encumbrance": 2, "shares pledged": 2,
    "fire at": 3, "plant shutdown": 3, "lock-out": 3, "lockout": 3,
    "labour strike": 3, "force majeure": 3, "suspension of operations": 4,
    "operations suspended": 4, "closure of plant": 3,
    "promoter sold": 3, "stake sale by promoter": 3, "decrease in promoter": 3,
    "offer for sale": 1, "net loss": 3, "loss widens": 3, "loss for the": 2,
}

# Greenblatt-style SPECIAL SITUATIONS — the event-driven edge most retail
# ignores. Phrase -> tag. Used by Solaimalai as a conviction BOOST (not a gate).
SPECIAL: dict[str, str] = {
    "buyback": "buyback", "buy-back": "buyback", "buy back of": "buyback",
    "demerger": "demerger", "de-merger": "demerger",
    "scheme of arrangement": "demerger", "composite scheme": "demerger",
    "amalgamation": "merger", "merger approval": "merger",
    "approval of merger": "merger", "approves merger": "merger",
    "spin-off": "spinoff", "spin off": "spinoff", "spinoff": "spinoff",
    "promoter acquired": "promoter-buying", "increase in promoter": "promoter-buying",
    "acquisition of shares by promoter": "promoter-buying",
    "preferential allotment to promoter": "promoter-buying",
    "open offer": "open-offer", "bonus issue": "bonus",
}


def special_situations(announcements: list[Announcement]) -> list[str]:
    """Distinct Greenblatt special-situation tags found in the filings."""
    tags = set()
    for a in announcements:
        for phrase, tag in SPECIAL.items():
            if phrase in a.text:
                tags.add(tag)
    return sorted(tags)


# Pure-noise subjects we never act on (so they don't dilute scoring).
NOISE = (
    "trading window", "newspaper publication", "compliance certificate",
    "disclosure under regulation 30", "investor presentation", "analyst meet",
    "earnings call", "schedule of analyst", "intimation of board meeting",
    "outcome of board meeting", "record of proceedings", "voting results",
    "loss of share certificate",  # routine investor-services notice
)


def classify(text: str) -> tuple[str, float, float, list[str]]:
    """Return (verdict, bull_score, bear_score, reasons).

    verdict is "bullish", "bearish" or "neutral". A single strong red-flag wins
    over bullish words (safety first)."""
    t = " ".join(text.lower().split())
    reasons: list[str] = []
    bull = 0.0
    for phrase, w in BULLISH.items():
        if phrase in t:
            bull += w
            reasons.append(f"+{phrase}")
    bear = 0.0
    for phrase, w in BEARISH.items():
        if phrase in t:
            bear += w
            reasons.append(f"-{phrase}")
    # Safety: any meaningful red flag blocks, even amid good words.
    if bear >= 3:
        return "bearish", bull, bear, reasons
    if bull >= 2 and bear == 0:
        return "bullish", bull, bear, reasons
    if bear > 0:
        return "bearish", bull, bear, reasons
    return "neutral", bull, bear, reasons


def assess(announcements: list[Announcement]) -> dict:
    """Aggregate a symbol's recent announcements into one verdict.

    Bearish (any red flag) wins; else bullish if any bullish filing; else
    neutral. Returns the driving headline(s) so the alert can explain itself."""
    if not announcements:
        return {"verdict": "neutral", "headline": "", "reasons": [],
                "bull": 0.0, "bear": 0.0, "n": 0, "special": []}
    special = special_situations(announcements)
    best_bull = None
    worst_bear = None
    for a in announcements:
        if any(n in a.text for n in NOISE) and not (
                any(p in a.text for p in BULLISH) or any(p in a.text for p in BEARISH)):
            continue  # pure noise, skip
        verdict, bull, bear, reasons = classify(a.text)
        if verdict == "bearish":
            if worst_bear is None or bear > worst_bear[1]:
                worst_bear = (a, bear, reasons)
        elif verdict == "bullish":
            if best_bull is None or bull > best_bull[1]:
                best_bull = (a, bull, reasons)
    if worst_bear is not None:
        a, bear, reasons = worst_bear
        return {"verdict": "bearish", "headline": a.subject, "reasons": reasons,
                "bull": 0.0, "bear": bear, "n": len(announcements), "special": special}
    if best_bull is not None:
        a, bull, reasons = best_bull
        return {"verdict": "bullish", "headline": a.subject, "reasons": reasons,
                "bull": bull, "bear": 0.0, "n": len(announcements), "special": special}
    return {"verdict": "neutral", "headline": "", "reasons": [],
            "bull": 0.0, "bear": 0.0, "n": len(announcements), "special": special}


# --- Fetch (network; isolated so the classifier tests run offline) ----------
_NSE_HOME = "https://www.nseindia.com"
_NSE_ANN = (_NSE_HOME +
            "/api/corporate-announcements?index=equities&symbol={sym}")
_HEADERS = {
    "User-Agent": ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                   "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": _NSE_HOME + "/companies-listing/corporate-filings-announcements",
}


def _within(date_str: str, days_back: int) -> bool:
    """True if an NSE announcement date is within the look-back window. NSE dates
    look like '23-Jun-2026 17:45:00' or ISO; be tolerant. Unknown -> keep."""
    if not date_str:
        return True
    cutoff = datetime.now() - timedelta(days=days_back)
    for fmt in ("%d-%b-%Y %H:%M:%S", "%d-%b-%Y", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d",
                "%d-%m-%Y %H:%M:%S", "%d-%m-%Y"):
        try:
            return datetime.strptime(date_str.strip()[:19], fmt) >= cutoff
        except ValueError:
            continue
    return True


def _fetch_nse(symbol: str, days_back: int, timeout: int) -> list[Announcement]:  # pragma: no cover
    """Pull recent announcements for an NSE symbol. Cookie-primed (NSE blocks
    cold requests). Returns [] on any failure — caller treats that as 'unknown'."""
    import http.cookiejar
    import urllib.request

    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

    def _get(url: str) -> bytes:
        req = urllib.request.Request(url, headers=_HEADERS)
        with opener.open(req, timeout=timeout) as r:
            return r.read()

    try:
        _get(_NSE_HOME)  # prime cookies
        raw = _get(_NSE_ANN.format(sym=urllib.request.quote(symbol)))
        data = json.loads(raw)
    except Exception:  # noqa: BLE001  (network/JSON/blocking — all -> unknown)
        return []

    rows = data if isinstance(data, list) else data.get("data", []) or []
    out: list[Announcement] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        date_str = (row.get("an_dt") or row.get("sort_date")
                    or row.get("exchdisstime") or "")
        if not _within(str(date_str), days_back):
            continue
        subject = (row.get("desc") or row.get("attchmntText")
                   or row.get("smIndustry") or "").strip()
        detail = (row.get("attchmntText") or row.get("desc") or "").strip()
        if not subject and not detail:
            continue
        out.append(Announcement(symbol=symbol, date=str(date_str),
                                subject=subject, detail=detail))
    return out


_NSE_MKT_ANN = (_NSE_HOME + "/api/corporate-announcements?index=equities"
                "&from_date={f}&to_date={t}")


def is_candidate(ann: Announcement) -> bool:
    """Cheap pre-filter (no AI): does this announcement look like a potential
    MATERIAL bullish catalyst worth a Gemini read? (order/contract/approval/
    buyback/etc., or a special situation). Keeps Gemini calls to a minimum."""
    verdict, _, _, _ = classify(ann.text)
    return verdict == "bullish" or bool(special_situations([ann]))


def fetch_market_announcements(days_back: int | None = None,
                               timeout: int | None = None) -> list[Announcement]:  # pragma: no cover
    """Pull recent NSE corporate announcements MARKET-WIDE (all companies), for
    the Swaminatha news face. Cookie-primed; [] on any failure. Each Announcement
    carries the company name in its detail so Gemini has context."""
    import http.cookiejar
    import urllib.request
    from datetime import date, timedelta

    days_back = config.NEWS_DAYS_BACK if days_back is None else days_back
    timeout = config.FILINGS_REQUEST_TIMEOUT if timeout is None else timeout
    today = date.today()
    frm = today - timedelta(days=days_back)
    url = _NSE_MKT_ANN.format(f=frm.strftime("%d-%m-%Y"), t=today.strftime("%d-%m-%Y"))

    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

    def _get(u: str) -> bytes:
        req = urllib.request.Request(u, headers=_HEADERS)
        with opener.open(req, timeout=timeout) as r:
            return r.read()

    try:
        _get(_NSE_HOME)  # prime cookies
        data = json.loads(_get(url))
    except Exception:  # noqa: BLE001
        return []

    rows = data if isinstance(data, list) else data.get("data", []) or []
    out: list[Announcement] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        symbol = (row.get("symbol") or "").strip().upper()
        if not symbol:
            continue
        name = (row.get("sm_name") or row.get("smName") or "").strip()
        subject = (row.get("desc") or row.get("attchmntText") or "").strip()
        detail = (row.get("attchmntText") or "").strip()
        date_str = (row.get("an_dt") or row.get("sort_date") or "")
        if not subject and not detail:
            continue
        # company name first so Gemini has context in the news text
        body = (f"{name}. " if name else "") + detail
        out.append(Announcement(symbol=symbol, date=str(date_str),
                                subject=subject, detail=body))
    return out


def fetch(symbol: str, days_back: int | None = None,
          timeout: int | None = None, source: str | None = None) -> list[Announcement]:
    """Fetch recent announcements for a symbol from the configured source."""
    days_back = config.FILINGS_DAYS_BACK if days_back is None else days_back
    timeout = config.FILINGS_REQUEST_TIMEOUT if timeout is None else timeout
    source = (source or config.FILINGS_SOURCE or "nse").lower()
    if source == "nse":
        return _fetch_nse(symbol, days_back, timeout)
    return []  # other sources (e.g. "bse") can be added here later


def assess_symbol(symbol: str, days_back: int | None = None,
                  fetcher=None) -> dict:
    """Fetch + classify one symbol. Returns assess() dict plus the symbol.
    On a fetch failure (empty AND we expected data) the verdict is 'unknown' so
    the caller can stay safe and not buy.

    `fetcher` is injectable for tests (a callable symbol -> list[Announcement]).

    NOTE: an LLM judge (e.g. Gemini) could be added here to re-rate 'neutral'
    cases by actually reading the filing PDF. Intentionally not wired yet."""
    fetcher = fetcher or fetch
    try:
        anns = fetcher(symbol)
    except Exception:  # noqa: BLE001
        anns = None
    if not anns:
        # Distinguish "couldn't fetch" from "genuinely nothing": we can't tell
        # for sure, so report 'unknown' — the safe, no-buy state.
        return {"symbol": symbol, "verdict": "unknown", "headline": "",
                "reasons": [], "bull": 0.0, "bear": 0.0, "n": 0, "special": []}
    result = assess(anns)
    result["symbol"] = symbol
    return result


def gate(verdicts: dict[str, dict]) -> dict:
    """Pure helper: split a {symbol: assess_dict} map into buy / block / skip.
    Only 'bullish' symbols are allowed to buy. Returns ordered buckets so the
    alert can explain the decision. Input order is preserved."""
    buy, blocked, neutral, unknown = [], [], [], []
    for sym, a in verdicts.items():
        v = a.get("verdict")
        if v == "bullish":
            buy.append(sym)
        elif v == "bearish":
            blocked.append(sym)
        elif v == "unknown":
            unknown.append(sym)
        else:
            neutral.append(sym)
    return {"buy": buy, "blocked": blocked, "neutral": neutral, "unknown": unknown}
