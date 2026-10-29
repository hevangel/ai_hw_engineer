#!/usr/bin/env python3
"""Exercise the real Verilator process through the Micral HTTP front panel.

Builds the system simulator directly (no shell wrapper), then runs two panel
sessions: the MO5 I/O demo (controls, POKE/SUB, TRAP) and the recovered
MIC-01 monitor ROM, entered through the manual's front-panel procedure
(R2E manual II.3.1) with teletype round-trips over HTTP.
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
    # The panel under test is the local simulator this script launches;
    # refuse any non-loopback target before opening the connection.
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "http" or parsed.hostname not in ("localhost", "127.0.0.1", "::1"):
        raise ValueError("panel URL must be loopback http: " + url)
    return url

def get(port):
    with urllib.request.urlopen(_checked(f"http://127.0.0.1:{port}/api/state"), timeout=10) as response:
        return json.load(response)

def post(port, action, **kwargs):
    payload = json.dumps({"action": action, **kwargs}).encode()
    request = urllib.request.Request(_checked(f"http://127.0.0.1:{port}/api/control"), payload,
                                     {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)

def post_tty(port, text):
    payload = json.dumps({"text": text}).encode()
    request = urllib.request.Request(_checked(f"http://127.0.0.1:{port}/api/tty"), payload,
                                     {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=10) as response:
        return json.load(response)

def prepare(image_bin, target_hex):
    subprocess.run([sys.executable, str(system / "scripts/prepare_image.py"),
                    str(image_bin), str(target_hex)], check=True)

def start_server(port, image_hex):
    env = dict(os.environ,
               MICRAL_SIMULATOR=str(build / "obj_dir/Vmicral_n"),
               MICRAL_IMAGE=str(image_hex),
               MICRAL_PORT=str(port))
    return subprocess.Popen([sys.executable, str(system / "host/server.py")],
                            stdout=logfile.open("a"), stderr=subprocess.STDOUT, env=env)

def wait_ready(process, port, timeout=30):
    deadline = time.monotonic() + timeout
    while True:
        if process.poll() is not None:
            raise RuntimeError(f"system process exited; see {logfile}")
        try:
            return get(port)
        except OSError:
            if time.monotonic() > deadline:
                raise RuntimeError(f"system startup timed out; see {logfile}")
            time.sleep(0.2)

verilator_build = ["verilator", "--cc", "--exe", "--build", "-j", "4", "-Wno-fatal",
                   "--top-module", "micral_n", "--Mdir", str(build / "obj_dir"),
                   str(root / "design/intel_mcs8/intel_8008/src/intel_8008.sv"),
                   str(system / "src/micral_n.sv"), str(system / "host/simulator.cpp")]
subprocess.run(verilator_build, check=True, stdout=logfile.open("w"))

mo5_io = build / "mo5_input_output.hex"
prepare(system / "src/rom/mo5_input_output.bin", mo5_io)
monitor_hex = build / "micral_rom.hex"
subprocess.run([sys.executable, str(system / "scripts/prepare_rom_image.py"),
                str(system / "src/rom/micral_bootloader.bin"),
                str(system / "src/rom/micral_monitor.bin"), str(monitor_hex)], check=True)

# ---- Phase A: MO5 I/O demo ----
process = start_server(8080, mo5_io)
try:
    initial = wait_ready(process, 8080)
    assert initial["pc"] == 0 and not initial["running"]
    stepped = post(8080, "STEP")
    assert stepped["instructions"] >= 1 and stepped["pc"] != initial["pc"]
    post(8080, "INPUT", value=128)
    post(8080, "AUTO")
    for _ in range(5):
        live = get(8080)
    assert live["instructions"] > 20
    assert live["lastOutputPort"] == 23 and live["lastOutputData"] > 0
    paused = post(8080, "PAUSE")
    assert not paused["running"]
    assert get(8080)["pc"] == paused["pc"]
    post(8080, "POKE", address=0x1000, value=0x5a)
    assert get(8080)["ram"][0] == 0x5a
    assert post(8080, "SUB", enabled=True, value=0xc0)["substitution"]
    reset = post(8080, "RESET")
    assert reset["pc"] == 0 and reset["instructions"] == 0

    # TRAP stops the run right after the instruction that retires with the
    # trap address as its PC.
    post(8080, "TRAP", enabled=True, address=1)
    post(8080, "AUTO")
    for _ in range(20):
        trapped = get(8080)
        if not trapped["running"]:
            break
    assert not trapped["running"] and trapped["pc"] == 1
    post(8080, "TRAP", enabled=False, address=1)
    print(f"PASS: HTTP/Verilator backend MO5 demo, {live['instructions']} instructions, "
          f"port 23 data {live['lastOutputData']:02x}, TRAP at {trapped['pc']:04x}")
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()

# ---- Phase B: recovered MIC-01 monitor via the manual panel procedure ----
process = start_server(8081, monitor_hex)
try:
    state = wait_ready(process, 8081)
    assert state["pc"] == 0
    # R2E manual II.3.1: with the machine in AUTO, substitute the bytes of
    # JMP $3B30 over the fetches at PC 0/1/2, then release SUB and run.
    for value in (0x44, 0x30, 0x3b):
        post(8081, "SUB", enabled=True, value=value)
        post(8081, "CYCLE")
    post(8081, "SUB", enabled=False, value=0)
    post(8081, "AUTO")
    for _ in range(10):
        state = get(8081)
        if state["tty"].startswith("8d0aa0"):
            break
    assert state["tty"].startswith("8d0aa0"), f"monitor prompt missing: {state['tty'][:32]}"
    assert state["pc"] >= 0x3800, f"monitor left ROM: pc={state['pc']:04x}"

    # Unknown command: the manual (II.3.2) echoes the letter, prints ': ',
    # then '?' for an unknown letter and returns to the prompt.
    post_tty(8081, "Z")
    for _ in range(10):
        state = get(8081)
        if "5a3aa03f" in state["tty"]:
            break
    assert "5a3aa03f" in state["tty"], f"unknown-command response missing: {state['tty'][-32:]}"

    # Memory command prompts for an address; CR cancels it.
    post_tty(8081, "M")
    for _ in range(10):
        state = get(8081)
        if state["tty"].endswith("4d3aa0"):
            break
    assert state["tty"].endswith("4d3aa0"), f"M prompt missing: {state['tty'][-24:]}"
    post_tty(8081, "\r")
    for _ in range(10):
        state = get(8081)
        if state["tty"].endswith("8d3f8d0aa0"):
            break
    assert state["tty"].endswith("8d3f8d0aa0"), f"cancel missing: {state['tty'][-24:]}"
    print("PASS: MIC-01 monitor over HTTP — panel procedure boots the ROM, prompt, "
          "unknown-command '?', M prompt, and CR cancel all round-trip through the ASR-33")
finally:
    process.terminate()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
