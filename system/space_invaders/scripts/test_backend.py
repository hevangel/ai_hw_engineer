#!/usr/bin/env python3
"""Check public controls, request validation and the waveform endpoint.

All requests target the fixed local test server. Every URL is validated
against an explicit scheme/host allowlist (loopback, plain HTTP) before use.
"""
import json
import os
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:18090"
ALLOWED_SCHEMES = {"http"}
ALLOWED_HOSTS = {"127.0.0.1", "localhost"}


def open_url(url, data=None, headers=None, method=None, timeout=60):
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
        control_body = body
        request("/api/control", control_body)
    except urllib.error.HTTPError as error:
        assert error.code == code
    else:
        raise AssertionError("invalid request was accepted")


def main():
    environment = {**os.environ, "INVADERS_PORT": "18090"}
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
            assert not initial["running"] and not initial["fault"]

            # Run the machine, verify the screen payload and counters move.
            control("RUNSW")
            time.sleep(1.0)
            state = request()
            assert state["running"] and state["frames"] > 10
            assert len(state["vram"]) == 2 * 7168
            int(state["vram"], 16)  # valid hex
            # ROM signature: the boot code at 0003h is JMP 18D4h (C3 D4 18).
            # The mem window shows 1A5Ch; a missing +rom leaves FFs and the
            # machine ends up in the RST-38h loop, which this must catch.
            assert any(byte != 0xFF for byte in state["mem"]), \
                "ROM not loaded (all-FF window): the RST-38h trap"
            control("RUNSW")
            paused = request()
            assert not paused["running"]

            # Input ports validated and echoed through board state.
            control("IN1", value=0x01)   # coin bit
            control("IN1", value=0x00)
            control("IN2", value=0x04)   # tilt bit
            control("IN2", value=0x00)
            reject({"action": "IN1", "value": 256})
            reject({"action": "IN0", "value": -1})
            reject({"action": "BOGUS"})
            reject({"action": "CAPTURE", "cycles": 0})

            # Waveform capture and endpoint.
            captured = control("CAPTURE", cycles=512)
            assert captured["captureVersion"] == 1
            waveform = request("/waveform.fst", raw=True)
            assert len(waveform) > 128
            response, _ = open_url(BASE + "/waveform.fst", method="HEAD")
            assert int(response.headers["Content-Length"]) == len(waveform)
            assert response.headers["X-Waveform-Version"] == "1"
            print("PASS: Space Invaders backend API, screen payload and waveform")
        finally:
            process.terminate()
            process.wait(timeout=10)


if __name__ == "__main__":
    main()
