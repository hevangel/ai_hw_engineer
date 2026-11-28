#!/usr/bin/env python3
"""Shared HTTP client and key-code mapping for the Busicom 141-PF panel bridge."""

from __future__ import annotations

import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

DEFAULT_URL = os.environ.get("BUSICOM_URL", "http://127.0.0.1:8080")

# Canonical scancodes matching host/web/index.html and spec/reference/Unicom_141P_examples.json.
KEY_CODES: dict[str, int] = {
    "0": 156,
    "1": 155,
    "2": 151,
    "3": 147,
    "4": 154,
    "5": 150,
    "6": 146,
    "7": 153,
    "8": 149,
    "9": 145,
    ".": 148,
    "00": 152,
    "+": 142,
    "-": 141,
    "*": 139,
    "/": 138,
    "=": 140,
    "%": 134,
    "ST": 137,
    "EX": 158,
    "CE": 159,
    "C": 160,
    "CM": 129,
    "RM": 130,
    "M-": 131,
    "M+": 132,
    "M=-": 135,
    "M=+": 136,
    "SIGN": 157,
    "SQRT": 133,
}

# User-friendly aliases accepted by the CLI and TUI.
KEY_ALIASES: dict[str, str] = {
    "#": "ST",
    "◇": "ST",
    "SUBTOTAL": "ST",
    "×": "*",
    "÷": "/",
    "−": "-",
    "√": "SQRT",
    "ENTER": "=",
    "TOTAL": "=",
    "CLEAR": "C",
    "CLR": "C",
    "S": "SIGN",
    "CS": "SIGN",
}

PRECISION_VALUES = (0, 1, 2, 3, 4, 5, 6, 8)
ROUNDING_MAP: dict[str | int, int] = {
    0: 0,
    1: 1,
    8: 8,
    "0": 0,
    "1": 1,
    "8": 8,
    "FL": 0,
    "FLOAT": 0,
    "5/4": 1,
    "ROUND": 1,
    "TRUNC": 8,
    "TRUNCATE": 8,
}
ROUNDING_LABELS: dict[int, str] = {
    0: "FL",
    1: "5/4",
    8: "TRUNC",
}

# Longest-first token pattern for compact expressions like "C14+29+=" or "M=+5M+".
_MULTI_TOKENS = sorted(
    [k for k in (*KEY_CODES.keys(), *KEY_ALIASES.keys()) if len(k) > 1],
    key=len,
    reverse=True,
)
_TOKEN_RE = re.compile(
    r"\s+|(" + "|".join(re.escape(t) for t in _MULTI_TOKENS) + r"|.)",
    re.IGNORECASE,
)


def normalize_key(token: str) -> str:
    """Normalize a key name or alias to its canonical KEY_CODES key."""
    upper = token.strip().upper()
    if upper in KEY_CODES:
        return upper
    if upper in KEY_ALIASES:
        return KEY_ALIASES[upper]
    raise ValueError(f"Unknown calculator key: {token!r}")


def parse_key_sequence(expr: str) -> list[str]:
    """Parse a string of calculator keys (spaced or compact) into canonical keys.

    Examples:
        "C 5 + 6 + =" -> ["C", "5", "+", "6", "+", "="]
        "C14+29+="    -> ["C", "1", "4", "+", "2", "9", "+", "=",]
        "M=+ 5 M+ RM" -> ["M=+", "5", "M+", "RM"]
    """
    keys: list[str] = []
    for match in _TOKEN_RE.finditer(expr):
        tok = match.group(1)
        if tok is None:
            continue
        keys.append(normalize_key(tok))
    return keys


def normalize_rounding(value: str | int) -> int:
    """Normalize a rounding mode ('fl', '5/4', 'trunc', 0, 1, 8) to bridge int."""
    key: str | int = value.strip().upper() if isinstance(value, str) else value
    if key not in ROUNDING_MAP:
        raise ValueError(
            f"Invalid rounding mode {value!r}; expected FL (0), 5/4 (1), or TRUNC (8)"
        )
    return ROUNDING_MAP[key]


def normalize_precision(value: int) -> int:
    """Validate decimal-point selector position (0..6 or 8)."""
    if value not in PRECISION_VALUES:
        raise ValueError(
            f"Invalid precision {value!r}; expected one of {PRECISION_VALUES}"
        )
    return value


def format_paper_row(cells: list[Any]) -> tuple[str, bool]:
    """Return (18-char text, is_red) for one row from state['paper']."""
    text = "".join(str(c) for c in cells[:18]).rstrip()
    is_red = bool(cells[18]) if len(cells) > 18 else False
    return text, is_red


class PanelClient:
    """HTTP client for the Busicom 141-PF panel_bridge.c API."""

    def __init__(self, url: str = DEFAULT_URL, timeout: float = 120.0) -> None:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != "http" or parsed.hostname not in (
            "localhost",
            "127.0.0.1",
            "::1",
        ):
            raise ValueError(f"Panel URL must be loopback http: {url}")
        self.url = url.rstrip("/")
        self.timeout = timeout
        self.history: dict[int, tuple[str, bool]] = {}

    def request(self, path: str, body: dict[str, Any] | None = None) -> dict[str, Any]:
        data = None if body is None else json.dumps(body).encode("utf-8")
        req = urllib.request.Request(
            self.url + path,
            data=data,
            headers={"Content-Type": "application/json"},
        )
        with urllib.request.urlopen(req, timeout=10) as response:
            raw = response.read().decode("utf-8", errors="replace")
            ctype = response.headers.get("Content-Type", "")
            status = getattr(response, "status", 200)
        if not raw.strip():
            raise RuntimeError(
                f"Empty response from {self.url}{path} (HTTP {status}). "
                "Check that the Busicom 141-PF simulator is running on this port "
                "(e.g. pass --url http://127.0.0.1:8081 if mapped to 8081)."
            )
        try:
            result = json.loads(raw)
        except json.JSONDecodeError as exc:
            preview = raw.strip().splitlines()[0][:120]
            raise RuntimeError(
                f"Non-JSON response from {self.url}{path} "
                f"(HTTP {status}, Content-Type: {ctype!r}): {preview!r}. "
                "Another service may be using this port."
            ) from exc
        if body is not None and result.get("ok") is not True:
            raise RuntimeError(f"{path} rejected: {result}")
        return result

    def _record_paper(self, state: dict[str, Any]) -> None:
        seq = state.get("paper_sequence")
        paper = state.get("paper", [])
        if isinstance(seq, int):
            base = seq - (len(paper) - 1)
            for idx, row in enumerate(paper):
                text, is_red = format_paper_row(row)
                if text or is_red:
                    self.history[base + idx] = (text, is_red)

    def state(self) -> dict[str, Any]:
        st = self.request("/state.json")
        self._record_paper(st)
        return st

    def wait_idle(self, timeout: float | None = None, poll_s: float = 0.05) -> dict[str, Any]:
        deadline = time.monotonic() + (self.timeout if timeout is None else timeout)
        last_error: str | None = None
        while time.monotonic() < deadline:
            try:
                st = self.state()
                if st.get("ready") and not st.get("busy"):
                    return st
            except (urllib.error.URLError, OSError, ValueError) as exc:
                last_error = str(exc)
            time.sleep(poll_s)
        raise TimeoutError(
            f"4004 did not become idle within {timeout or self.timeout}s"
            + (f" ({last_error})" if last_error else "")
        )

    def press(self, key: str | int, wait: bool = True) -> dict[str, Any]:
        if isinstance(key, int):
            code = key
            if not (129 <= code <= 160):
                raise ValueError(f"Key code out of range (129..160): {code}")
        else:
            code = KEY_CODES[normalize_key(key)]
        res = self.request("/press", {"code": code})
        return self.wait_idle() if wait else res

    def press_sequence(self, tokens: str | list[str], wait: bool = True) -> dict[str, Any]:
        keys = parse_key_sequence(tokens) if isinstance(tokens, str) else [
            normalize_key(t) for t in tokens
        ]
        if not keys:
            return self.state()
        st: dict[str, Any] = {}
        for k in keys:
            st = self.press(k, wait=wait)
        return st

    def advance(self, wait: bool = True) -> dict[str, Any]:
        res = self.request("/advance", {})
        return self.wait_idle() if wait else res

    def set_switches(
        self,
        precision: int | None = None,
        rounding: str | int | None = None,
    ) -> dict[str, Any]:
        payload: dict[str, int] = {}
        if precision is not None:
            payload["precision"] = normalize_precision(precision)
        if rounding is not None:
            payload["rounding"] = normalize_rounding(rounding)
        if not payload:
            return {"ok": True}
        return self.request("/switches", payload)

    def tape_lines(self) -> list[tuple[int, str, bool]]:
        """Return accumulated tape history sorted by paper_sequence."""
        return [(seq, text, red) for seq, (text, red) in sorted(self.history.items())]
