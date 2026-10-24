#!/usr/bin/env python3
"""Exercise the real Verilator process through the Micral HTTP front panel."""
from pathlib import Path
import json
import subprocess
import time
import urllib.parse
import urllib.request

system = Path(__file__).resolve().parents[1]
logfile = system / "build/backend_test.log"
logfile.parent.mkdir(parents=True, exist_ok=True)

def _checked(url):
    # The panel under test is the local simulator this script launches;
    # refuse any non-loopback target before opening the connection.
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "http" or parsed.hostname not in ("localhost", "127.0.0.1", "::1"):
        raise ValueError("panel URL must be loopback http: " + url)
    return url

def get():
    with urllib.request.urlopen(_checked("http://127.0.0.1:8080/api/state"), timeout=5) as response:
        return json.load(response)

def post(action, **kwargs):
    payload = json.dumps({"action": action, **kwargs}).encode()
    request = urllib.request.Request(_checked("http://127.0.0.1:8080/api/control"), payload,
                                     {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=5) as response:
        return json.load(response)

with logfile.open("w") as log:
    process = subprocess.Popen(["sh", str(system / "scripts/run_system.sh")],
                               stdout=log, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 90
        while True:
            if process.poll() is not None:
                raise RuntimeError(f"system process exited; see {logfile}")
            try:
                initial = get()
                break
            except OSError:
                if time.monotonic() > deadline:
                    raise RuntimeError(f"system startup timed out; see {logfile}")
                time.sleep(0.2)
        assert initial["pc"] == 0 and not initial["running"]
        stepped = post("STEP")
        assert stepped["instructions"] >= 1 and stepped["pc"] != initial["pc"]
        post("INPUT", value=128)
        post("AUTO")
        for _ in range(5):
            live = get()
        assert live["instructions"] > 20
        assert live["lastOutputPort"] == 23 and live["lastOutputData"] > 0
        paused = post("PAUSE")
        assert not paused["running"]
        assert get()["pc"] == paused["pc"]
        post("POKE", address=0x1000, value=0x5a)
        assert get()["ram"][0] == 0x5a
        assert post("SUB", enabled=True, value=0xc0)["substitution"]
        reset = post("RESET")
        assert reset["pc"] == 0 and reset["instructions"] == 0
        print(f"PASS: HTTP/Verilator backend, PC={paused['pc']:04x}, "
              f"{live['instructions']} instructions, port 23 data {live['lastOutputData']:02x}")
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
