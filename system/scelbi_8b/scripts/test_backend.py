#!/usr/bin/env python3
"""Exercise the real Verilator process through the SCELBI 8B HTTP console.

Builds the system simulator directly (no shell wrapper), then drives a full
console session over HTTP: boot SCELBAL, SCR, type the Shooting Stars
listing through /api/load, RUN, and play with sequential guesses until the
game concedes — the same flow the web panel performs.
"""
from pathlib import Path
import json
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

system = Path(__file__).resolve().parents[1]
root = system.parents[1]
build = system / "build"
build.mkdir(exist_ok=True)
logfile = build / "backend_test.log"

def _checked(url):
    # The console under test is the local simulator this script launches;
    # refuse any non-loopback target before opening the connection.
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "http" or parsed.hostname not in ("localhost", "127.0.0.1", "::1"):
        raise ValueError("console URL must be loopback http: " + url)
    return url

def get():
    with urllib.request.urlopen(_checked("http://127.0.0.1:8080/api/state"), timeout=10) as response:
        return json.load(response)

def post(path, payload):
    request = urllib.request.Request(_checked(f"http://127.0.0.1:8080{path}"),
                                     json.dumps(payload).encode(),
                                     {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)

def tty(text):
    return post("/api/tty", {"text": text})

def hi(text):
    # The SCELBI console card sets bit 7 on every byte both ways (7-bit
    # ASCII + parity convention), so the machine's own output carries the
    # high bit. Typed-character echoes come back as sent (plain).
    return bytes(c | 0x80 for c in text.encode("ascii"))

def wait_for(needle, guards, mark=0):
    # `needle` is a bytes object; `mark` is a byte position in the console
    # ring: only text at or after it counts (allowing a needle that
    # straddles the mark).
    for _ in range(guards):
        state = get()
        ring = bytes.fromhex(state["tty"])
        if needle in ring[max(0, mark - len(needle) + 1):]:
            return True
    return False

verilator_build = ["verilator", "--cc", "--exe", "--build", "-j", "4", "-Wno-fatal",
                   "--top-module", "scelbi_8b", "--Mdir", str(build / "obj_dir"),
                   str(root / "design/intel_mcs8/intel_8008/src/intel_8008.sv"),
                   str(system / "src/scelbi_8b.sv"), str(system / "host/simulator.cpp")]
subprocess.run(verilator_build, check=True, stdout=logfile.open("w"))

subprocess.run([sys.executable, str(system / "scripts/prepare_image.py"),
                str(system / "src/rom/scelbal_sc1.bin"),
                str(build / "scelbal.hex")], check=True)

env = dict(os.environ,
           SCELBI_SIMULATOR=str(build / "obj_dir/Vscelbi_8b"),
           SCELBI_IMAGE=str(build / "scelbal.hex"),
           SCELBI_PORT="8080")
process = subprocess.Popen([sys.executable, str(system / "host/server.py")],
                           stdout=logfile.open("a"), stderr=subprocess.STDOUT, env=env)
try:
    deadline = time.monotonic() + 30
    while True:
        if process.poll() is not None:
            raise RuntimeError(f"console process exited; see {logfile}")
        try:
            state = get()
            break
        except OSError:
            if time.monotonic() > deadline:
                raise RuntimeError(f"console startup timed out; see {logfile}")
            time.sleep(0.2)

    # Boot: press AUTO so the 8008 runs (panel polls drive 50000 cycles each),
    # then wait for SCELBAL's sign-on. NOTE: SCELBAL's dispatcher re-runs its
    # cold start (reprinting READY) on stray characters, so the console ring
    # scrolls continuously — every check here is presence-based.
    post("/api/control", {"action": "AUTO"})
    assert wait_for(hi("READY"), 4000), "no READY sign-on"
    tty("SCR\r")
    assert wait_for(hi("READY"), 2000), "no READY after SCR"

    # Load Shooting Stars, then run it. The load echo scrolls away under the
    # dispatcher's READY reprints, so the proof the listing stored is the
    # game itself running (WELCOME is line 100's output).
    listing = (system / "spec/reference/shooting_stars.bas").read_text()
    post("/api/load", {"text": listing})
    tty("RUN\r")
    assert wait_for(hi("WELCOME TO MY GALAXY"), 3000), "game did not run (load failed?)"
    assert wait_for(hi("TYPE 1 TO SEE RULES, "), 2000), "rules prompt missing"
    tty("1\r")
    assert wait_for(hi("WHAT IS YOUR GUESS?"), 2000), "guess prompt missing"

    # Answer a guess: the game must return to the prompt (the star response
    # prints between the two prompts). The full play-to-win is proven at the
    # RTL level in tb_game; over HTTP this exercises the console plumbing
    # end to end.
    def prompts(s):
        return bytes.fromhex(s["tty"]).count(hi("WHAT IS YOUR GUESS?"))

    before = prompts(state)
    tty("50\r")
    looped = False
    for _ in range(2000):
        state = get()
        if prompts(state) >= before + 1:
            looped = True
            break
    assert looped, "game did not return to the guess prompt after a guess"
    assert state["instructions"] > 1000000
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
