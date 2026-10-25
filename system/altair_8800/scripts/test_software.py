#!/usr/bin/env python3
"""Real-software regression: boot original Altair 4K BASIC 3.2.

The 20-byte MITS SIO bootstrap is toggled in through the front panel
(DEPOSIT/DEPOSIT NEXT), the machine runs, the original 4K BASIC 3.2 tape is
fed through the 88-SIO at ports 0/1, the startup prompts are answered like a
teletype operator would, and a small program is run. Everything executes in
RTL; the host only drives panel switches and the serial line.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TAPE = ROOT / "work/4kbas32.tap"

# MITS SIO bootstrap for 4K BASIC 3.2, spec/reference/LDR4K32-octal.PRN:
# 21 AE 0F 31 12 00 DB 00 0F D8 DB 01 BD C8 2D 77 C0 E9 03 00
BOOTSTRAP = bytes.fromhex("21ae0f311200db000fd8db01bdc82d77c0e90300")

PROMPTS = [
    (b"MEMORY SIZE", b"\r"),
    (b"TERMINAL WIDTH", b"\r"),
    (b"WANT SIN", b"N\r"),
    (b"WANT RND", b"N\r"),
    (b"WANT SQR", b"N\r"),
]


class Simulator:
    def __init__(self):
        self.process = subprocess.Popen(
            [str(ROOT / "work/obj/Valtair_8800")],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)

    def command(self, line):
        self.process.stdin.write(line + "\n")
        self.process.stdin.flush()
        out = self.process.stdout.readline()
        if not out:
            raise RuntimeError("RTL simulator exited")
        data = json.loads(out)
        if "error" in data:
            raise RuntimeError(f"{line!r}: {data['error']}")
        return data

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write("QUIT\n")
            self.process.stdin.flush()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()


def send_keys(sim, text):
    for byte in text.encode():
        sim.command(f"KEY {byte}")


def console_text(state):
    return "".join(chr(byte & 0x7F) for byte in state["tx"])


def main():
    if not TAPE.exists():
        raise SystemExit("run scripts/fetch_firmware.py first")
    sim = Simulator()
    try:
        # Toggle the bootstrap in through the panel, exactly as documented.
        sim.command("RESET")
        sim.command(f"SWITCHES 0 {BOOTSTRAP[0]}")
        sim.command("DEPOSIT")
        for byte in BOOTSTRAP[1:]:
            sim.command(f"SWITCHES 0 {byte}")
            sim.command("DEPNEXT")
        checked = sim.command("SWITCHES 0 0")
        checked = sim.command("EXAMINE")
        if checked["lampData"] != BOOTSTRAP[0]:
            raise AssertionError("bootstrap byte 0 did not deposit correctly")

        # RUN with the tape in the reader (the 88-SIO data path).
        sim.command("TAPE " + str(TAPE))
        sim.command("RUNSW 1")
        text = ""
        ticks = 0
        pending = list(PROMPTS)
        while pending:
            state = sim.command("RUN 50000")
            ticks = state["cycles"]
            text += console_text(state)
            marker, reply = pending[0]
            if marker.decode() in text:
                send_keys(sim, reply.decode())
                pending.pop(0)
            if ticks > 8_000_000:
                raise AssertionError(f"stuck before {marker.decode()}; tail: {text[-200:]!r}")
        print(f"4K BASIC 3.2 answered its startup prompts after {ticks} steps")

        # Run a real program and require the exact responses.
        for line, expect in [
            ("PRINT 2+2", " 4"),
            ("PRINT 3/8", " .375"),
            ("10 FOR I=1 TO 3", ""),
            ("20 PRINT I", ""),
            ("30 NEXT I", ""),
            ("RUN", " 1"),
            ('PRINT "ALTAIR"', '"ALTAIR"'),
        ]:
            before = len(text)
            state = sim.command("KEY " + str((line + "\r").encode()[0]))
            for byte in (line + "\r").encode()[1:]:
                state = sim.command(f"KEY {byte}")
            text += console_text(state)
            for _ in range(200):
                if expect and expect in text[before:]:
                    break
                state = sim.command("RUN 50000")
                text += console_text(state)
            if expect and expect not in text[before:]:
                raise AssertionError(f"BASIC did not answer {line!r} with {expect!r}; "
                                     f"tail: {text[before:before + 200]!r}")
            print(f"  {line} -> {expect!r}")

        # Stop the machine; the panel must regain the bus.
        sim.command("RUNSW 0")
        state = sim.command("STATE")
        if not state["hlda"]:
            raise AssertionError("panel did not regain the bus after STOP")
        if "BASIC VERSION 3.2" not in text or "[4K VERSION]" not in text:
            raise AssertionError("version banner missing from boot transcript")
        print(text[-400:])
        print("PASS: Altair 8800 booted original 4K BASIC 3.2 via panel and tape")
    finally:
        sim.close()


if __name__ == "__main__":
    sys.exit(main())
