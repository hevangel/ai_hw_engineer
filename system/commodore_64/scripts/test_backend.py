#!/usr/bin/env python3
"""Check public controls, request validation and the waveform endpoint.

All requests target the fixed local test server. Every URL is validated
against an explicit scheme/host allowlist (loopback, plain HTTP) before use.
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from c64sim import petscii_screen  # noqa: E402

BASE = "http://127.0.0.1:18091"
ALLOWED_SCHEMES = {"http"}
ALLOWED_HOSTS = {"127.0.0.1", "localhost"}


def open_url(url, data=None, headers=None, method=None, timeout=600):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ALLOWED_SCHEMES or parts.hostname not in ALLOWED_HOSTS:
        raise AssertionError(f"test request rejected by allowlist: {url}")
    req = urllib.request.Request(url, data, headers or {}, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response, response.read()


def request(path="/api/state", body=None, raw=False):
    data = json.dumps(body).encode() if isinstance(body, dict) else body
    headers = {"Content-Type": "application/json"} if isinstance(body, dict) else {}
    _, content = open_url(BASE + path, data, headers)
    return content if raw else json.loads(content)


def control(action, **kwargs):
    return request("/api/control", {"action": action, **kwargs})


def reject(body, code=400):
    try:
        request("/api/control", body)
    except urllib.error.HTTPError as error:
        assert error.code == code
    else:
        raise AssertionError("invalid request was accepted")


def screen(state):
    return petscii_screen(bytes.fromhex(state["text"]))


def main():
    environment = {**os.environ, "C64_PORT": "18091"}
    with (ROOT / "work/backend_server.log").open("w") as log:
        process = subprocess.Popen(["python3", str(ROOT / "host/server.py")],
                                   env=environment, stdout=log,
                                   stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            while True:
                try:
                    assert request("/api/health")["ok"]
                    break
                except OSError:
                    if process.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError("backend startup failed; inspect log")
                    time.sleep(0.1)

            initial = request()
            assert not initial["running"] and not initial["jammed"]
            assert initial["rows"] == 312 and initial["cols"] == 520
            assert len(initial["frame"]) == 312 * 520

            # Boot through the front panel's own polling path.
            control("RUNSW")
            state = request()
            while state["frames"] < 140:
                state = request()
            assert "READY." in screen(state), "BASIC did not reach READY."
            int(state["frame"], 16)  # valid hex raster

            # Typing is queued server-side and drained by polls.
            state = control("TYPE", text="PRINT 6*7\n")
            while state["queued"]:
                state = request()
            for _ in range(5):
                state = request()
            assert " 42" in screen(state), "\n".join(screen(state))

            control("STOPRESTORE")
            for _ in range(20):
                state = request()
            assert screen(state)[1] == "READY.", "RUN/STOP+RESTORE warm start"
            control("RUNSW")
            assert not request()["running"]

            control("JOY2", value=0x0f)
            control("JOY2", value=0x1f)
            control("KEYS", keys=["LSHIFT"])
            control("KEYS", keys=[])
            reject({"action": "JOY2", "value": 32})
            reject({"action": "KEYS", "keys": ["NOPE"]})
            reject({"action": "TYPE", "text": "\x01"})
            reject({"action": "BOGUS"})
            reject({"action": "CAPTURE", "cycles": 0})

            # Waveform capture and endpoint.
            captured = control("CAPTURE", cycles=256)
            assert captured["captureVersion"] == 1
            waveform = request("/waveform.fst", raw=True)
            assert len(waveform) > 128
            response, _ = open_url(BASE + "/waveform.fst", method="HEAD")
            assert int(response.headers["Content-Length"]) == len(waveform)
            assert response.headers["X-Waveform-Version"] == "1"
            print("PASS: Commodore 64 backend API, typing, warm start and waveform")
        finally:
            process.terminate()
            process.wait(timeout=10)


if __name__ == "__main__":
    main()
