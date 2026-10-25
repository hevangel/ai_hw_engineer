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
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:18080"
ALLOWED_SCHEMES = {"http"}
ALLOWED_HOSTS = {"127.0.0.1", "localhost"}


def open_url(url, data=None, headers=None, method=None, timeout=60):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ALLOWED_SCHEMES or parts.hostname not in ALLOWED_HOSTS:
        raise AssertionError(f"test request rejected by allowlist: {url}")
    req = urllib.request.Request(url, data, headers or {}, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response, response.read()


def request(path="/api/state", body=None, raw=False, method=None):
    data = json.dumps(body).encode() if isinstance(body, dict) else body
    headers = {"Content-Type": "application/json"} if isinstance(body, dict) else {}
    _, content = open_url(BASE + path, data, headers, method=method)
    return content if raw else json.loads(content)


def control(action, **kwargs):
    return request("/api/control", {"action": action, **kwargs})


def reject(path, body, code=400):
    try:
        request(path, body)
    except urllib.error.HTTPError as error:
        assert error.code == code
    else:
        raise AssertionError("invalid request was accepted")


def main():
    environment = {**os.environ, "ALTAIR_PORT": "18080"}
    with (ROOT / "work/backend_server.log").open("w") as log:
        process = subprocess.Popen(["python3", str(ROOT / "host/server.py")], env=environment,
                                   stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 20
            while True:
                try:
                    assert request("/api/health")["ok"]
                    break
                except OSError:
                    if process.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError("backend startup failed; inspect backend_server.log")
                    time.sleep(0.1)

            initial = request()
            assert not initial["running"] and initial["cycles"] == 0 and not initial["fault"]

            # Panel deposits through the API, verified by EXAMINE.
            control("RESET")
            control("SWITCHES", address=0, data=0x21)
            control("DEPOSIT")
            control("SWITCHES", address=0, data=0x55)
            state = control("EXAMINE")
            assert state["lampData"] == 0x21 and state["lampAddr"] == 0
            assert state["displayAddr"] == 0
            state = control("DEPNEXT")
            assert state["lampData"] == 0x55 and state["displayAddr"] == 1
            assert state["lampAddr"] == 1
            assert state["mem"][0] == 0x21 and state["mem"][1] == 0x55

            # Invalid requests are rejected with 400.
            reject("/api/control", {"action": "SWITCHES", "address": 70000, "data": 0})
            reject("/api/control", {"action": "KEY", "keys": [999]})
            reject("/api/control", {"action": "BOGUS"})
            reject("/api/tape", b"x" * 65537)

            # Console input reaches the SIO; bytes come back on tx. A tiny
            # echo program: IN 00/ANI 01/JNZ; IN 01; OUT 01; JMP.
            program = bytes.fromhex("db00e601c20000db01d301c30000")
            control("RESET")
            for index, byte in enumerate(program):
                control("SWITCHES", address=0, data=byte)
                control("DEPOSIT" if index == 0 else "DEPNEXT")
            control("RESET")
            control("RUNSW", value=1)
            state = control("KEY", keys=[0x41])
            for _ in range(50):
                if any(byte == 0x41 for byte in state["tx"]):
                    break
                state = request()
            assert any(byte == 0x41 for byte in state["tx"]), "SIO echo loop failed"

            # Pause serialization and poll burst behavior.
            with ThreadPoolExecutor(max_workers=2) as pool:
                polling = pool.submit(request)
                paused = control("RUNSW", value=0)
                polling.result()
            assert not paused["running"]
            assert request()["cycles"] == request()["cycles"] == paused["cycles"]

            # Waveform capture and endpoint.
            reject("/api/control", {"action": "CAPTURE", "cycles": 0})
            captured = control("CAPTURE", cycles=512)
            assert captured["captureVersion"] == 1
            # The convenience action loads the cached 4K BASIC tape.
            loaded = control("LOADBASIC")
            assert loaded["tapePending"] > 1000
            control("TAPEOFF")
            waveform = request("/waveform.fst", raw=True)
            assert len(waveform) > 128
            response, _ = open_url(BASE + "/waveform.fst", method="HEAD")
            assert int(response.headers["Content-Length"]) == len(waveform)
            assert response.headers["X-Waveform-Version"] == "1"
            print("PASS: Altair 8800 backend API, validation and waveform endpoint")
        finally:
            process.terminate()
            process.wait(timeout=10)


if __name__ == "__main__":
    main()
