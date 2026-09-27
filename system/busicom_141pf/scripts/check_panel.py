#!/usr/bin/env python3
"""Check exact paper output from the original firmware over the panel API."""
import json
import re
import sys
import time
import urllib.error
import urllib.request


BASE = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8080"
KEYS = {"C": 160, "0": 156, "1": 155, "2": 151, "3": 147,
        "4": 154, "5": 150, "6": 146, "7": 153, "8": 149,
        "9": 145, "+": 142, "-": 141, "*": 139, "=": 140}


def request(path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(BASE + path, data,
                                 {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as response:
        return json.load(response)


def wait_idle(timeout):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            state = request("/state.json")
            if state.get("ready") and not state["busy"]:
                return state
        except (urllib.error.URLError, TimeoutError):
            pass
        time.sleep(0.2)
    raise AssertionError("Panel did not become ready and idle")


def check(sequence, expected):
    for key in sequence:
        request("/press", {"code": KEYS[key]})
        state = wait_idle(120)
    rows = ["".join(row[:18]).rstrip() for row in state["paper"]]
    # Compare the latest total, not a stale digit elsewhere on the tape.
    totals = [row for row in rows if row.endswith("*")]
    assert totals and re.fullmatch(r"\s*" + re.escape(expected) + r"\s+\*",
                                  totals[-1]), (sequence, expected, rows)
    print(f"PASS {sequence}: {totals[-1].strip()}", flush=True)


print("Waiting for firmware boot...", flush=True)
wait_idle(300)
if "--decimal" in sys.argv:
    request("/switches", {"precision": 2, "rounding": 0})
    check("C1+2+=", "3.00")
else:
    request("/switches", {"precision": 0, "rounding": 0})
    # Kintli's firmware table: + accumulates each entry, = recalls total.
    check("C1+2+=", "3")
    check("C5+6+=", "11")
    check("C9*3=", "27")
    check("C14+29+=", "43")
    check("C9+3-=", "6")
