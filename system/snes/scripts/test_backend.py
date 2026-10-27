#!/usr/bin/env python3
"""Check public controls, request validation, the screen/audio payload, ROM
loading and the waveform endpoint of the SNES panel backend.

All requests target the fixed local test server. Every URL is validated
against an explicit scheme/host allowlist (loopback, plain HTTP) before use.
"""
import base64
import json
import os
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "http://127.0.0.1:18092"
HELLO = "peterlemon/HelloWorld/HelloWorld.sfc"
OTHER = "peterlemon/CPUTest/CPU/ADC/CPUADC.sfc"
ALLOWED_SCHEMES = {"http"}
ALLOWED_HOSTS = {"127.0.0.1", "localhost"}


def open_url(url, data=None, headers=None, method=None, timeout=120):
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
        assert error.code == code, error.code
    else:
        raise AssertionError(f"invalid request was accepted: {body}")


def main():
    environment = {**os.environ, "SNES_PORT": "18092"}
    with (ROOT / "work/backend_server.log").open("w") as log:
        process = subprocess.Popen(["python3", str(ROOT / "host/server.py")],
                                   env=environment, stdout=log, stderr=subprocess.STDOUT)
        try:
            deadline = time.monotonic() + 30
            while True:
                try:
                    assert request("/api/health")["ok"]
                    break
                except OSError:
                    if process.poll() is not None or time.monotonic() > deadline:
                        raise RuntimeError("backend startup failed; inspect log")
                    time.sleep(0.2)

            roms = request("/api/roms")
            assert roms["current"] == HELLO, roms["current"]
            assert OTHER in roms["roms"]

            # The board powers up running; HelloWorld draws its text.
            state = request()
            while state["frames"] < 20:
                state = request()
            assert state["running"] and not state["overrun"]
            screen = base64.b64decode(state["screen"])
            assert len(screen) == 512 * 240 * 2
            assert len(set(screen[:512 * 224 * 2:2])) >= 2, "HelloWorld text not drawn"
            assert len(base64.b64decode(state["audio"])) % 4 == 0

            # Controller input, stop/run switch, reset.
            assert control("PAD1", value=0x808)["pad1"] == 0x808
            assert control("PAD1", value=0x00)["pad1"] == 0x00
            paused = control("RUNSW")
            assert not paused["running"]
            assert request()["frames"] == paused["frames"]
            control("RUNSW")
            assert control("RESET")["running"]
            reject({"action": "PAD1", "value": 4096})
            reject({"action": "PAD2", "value": -1})
            reject({"action": "LOAD", "rom": "../../etc/passwd"})
            reject({"action": "BOGUS"})
            reject({"action": "CAPTURE", "cycles": 0})

            # Load another cartridge (power cycle).
            loaded = control("LOAD", rom=OTHER)
            assert loaded["rom"] == OTHER and loaded["frames"] == 0

            # Waveform capture and endpoint.
            captured = control("CAPTURE", cycles=2000)
            assert captured["captureVersion"] == 1
            waveform = request("/waveform.fst", raw=True)
            assert len(waveform) > 128
            response, _ = open_url(BASE + "/waveform.fst", method="HEAD")
            assert int(response.headers["Content-Length"]) == len(waveform)
            assert response.headers["X-Waveform-Version"] == "1"
            print("PASS: SNES backend API, screen/audio payload, ROM loading and waveform")
        finally:
            process.terminate()
            process.wait(timeout=10)


if __name__ == "__main__":
    main()
