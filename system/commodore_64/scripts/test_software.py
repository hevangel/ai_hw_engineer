#!/usr/bin/env python3
"""Original-ROM regression on the RTL C64.

Stages: power-on banner and READY; typed direct-mode and stored BASIC;
pixel-exact text screen against an independent renderer (screen RAM, color
RAM and the character ROM); a SID voice whose measured pitch matches its
frequency register; joystick port 2 through CIA1; CIA1 time-of-day counting
from the mains TOD input; and RUN/STOP + RESTORE through NMI.

usage: test_software.py [--ntsc]
"""
import math
import sys
from pathlib import Path

SYSTEM = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SYSTEM / "scripts"))
from c64sim import C64  # noqa: E402
import c64_keys  # noqa: E402

NTSC = "--ntsc" in sys.argv
CHARGEN = (SYSTEM / "work/chargen.bin").read_bytes()
PHI2 = 1022727 if NTSC else 985248


def check(condition, message):
    if not condition:
        raise SystemExit(f"FAIL: {message}")
    print(f"  ok: {message}")


def find(lines, text):
    return [i for i, line in enumerate(lines) if line == text]


def render_text(state):
    """Independent 40x25 standard-text renderer (VIC bank 0, $D018 = $15)."""
    text = bytes.fromhex(state["text"])
    color = bytes.fromhex(state["color"])
    image = [[0] * 320 for _ in range(200)]
    for row in range(25):
        for col in range(40):
            code = text[row * 40 + col]
            for line in range(8):
                bits = CHARGEN[code * 8 + line]
                for x in range(8):
                    fg = (bits >> (7 - x)) & 1
                    image[row * 8 + line][col * 8 + x] = color[row * 40 + col] if fg else 6
    return image


def compare_frame(state):
    frame, cols = state["frame"], state["cols"]
    want = render_text(state)
    # Locate the 320x200 window: its top-left pixel is the first non-border
    # pixel of the first display row, and must be unique.
    best = None
    for top in range(0, state["rows"] - 200):
        for left in range(0, cols - 320):
            if all(int(frame[(top + y) * cols + left + x], 16) == want[y][x]
                   for y, x in ((0, 0), (0, 1), (199, 319), (100, 160), (8, 8))):
                if all(int(frame[(top + y) * cols + left + x], 16) == want[y][x]
                       for y in range(200) for x in range(320)):
                    best = (top, left)
                    break
        if best:
            break
    return best


def tone_frequency(samples, rate=44100.0):
    crossings = [i for i in range(1, len(samples)) if samples[i - 1] < 0 <= samples[i]]
    if len(crossings) < 10:
        return 0.0
    return rate * (len(crossings) - 1) / (crossings[-1] - crossings[0])


def main():
    machine = C64(variant=1 if NTSC else 0)
    try:
        print("== Power-on and BASIC banner")
        machine.command("RUN 160")
        lines = machine.screen()
        check(lines[1] == "    **** COMMODORE 64 BASIC V2 ****", "banner line")
        check(lines[3] == " 64K RAM SYSTEM  38911 BASIC BYTES FREE", "38911 bytes free")
        check(lines[5] == "READY.", "READY prompt")
        pc = machine.command("STATE")["pc"]
        check(0xe5cd <= pc <= 0xe5d6, f"KERNAL keyboard wait loop (PC ${pc:04X})")

        print("== Text screen pixels against an independent renderer")
        state = machine.command("RUNF 1")
        window = compare_frame(state)
        check(window is not None, f"320x200 display window pixel-exact at row/col {window}")
        border = int(state["frame"][(window[0] - 10) * state["cols"] + window[1] + 10], 16)
        check(border == 14, "light-blue border (color 14)")

        print("== Typed BASIC")
        machine.type("PRINT 2+2\n")
        machine.command("RUN 5")
        lines = machine.screen()
        check(find(lines, " 4") != [], "PRINT 2+2 prints 4")
        machine.type("10 FOR I=1 TO 5:PRINT I*I;:NEXT\nRUN\n")
        machine.command("RUN 20")
        check(find(machine.screen(), " 1  4  9  16  25") != [], "stored program prints squares")

        print("== SID voice 1 triangle")
        machine.type("POKE54296,15:POKE54277,0:POKE54278,240:POKE54273,34:POKE54272,75:POKE54276,17\n")
        machine.command("RUN 10")
        samples = []
        for _ in range(4):
            samples += machine.command("RUNF 5")["audio"]
        frequency = tone_frequency(samples)
        want = 0x224b * PHI2 / 16777216
        check(abs(frequency - want) / want < 0.02,
              f"measured {frequency:.1f} Hz for frequency register $224B (expected {want:.1f} Hz)")
        machine.type("POKE54276,16\n")

        print("== Joystick port 2 through CIA1 port A")
        machine.type("PRINT \"J\"PEEK(56320)\n")
        machine.command("JOY2 15")          # fire held while the statement runs
        machine.command("RUN 20")
        machine.command("JOY2 31")
        lines = machine.screen()
        check(find(lines, "J 111") != [] or find(lines, "J 127") != [],
              "PEEK(56320) reads port A")
        # A held key would stop the scan; read with the keyboard idle instead.
        machine.type("POKE 56322,0:FOR T=1 TO 2:NEXT:J=PEEK(56320):POKE 56322,255:PRINT \"K\"J\n")
        machine.command("JOY2 15")
        machine.command("RUN 30")
        machine.command("JOY2 31")
        lines = machine.screen()
        check(find(lines, "K 239") != [], "fire button clears CIA1 PA4 (reads 239 with port A as input)")

        print("== CIA1 time of day")
        machine.type("POKE56335,PEEK(56335)AND127:POKE56331,0:POKE56330,0:POKE56329,0:POKE56328,0\n")
        machine.command("RUN 120")
        machine.type("PRINT \"T\"PEEK(56329)\n")
        machine.command("RUN 5")
        lines = machine.screen()
        seconds = [line for line in lines if line.startswith("T ")]
        check(seconds and int(seconds[-1][2:]) in (2, 3, 4),
              f"TOD seconds advanced from the {50 if not NTSC else 60} Hz input ({seconds[-1:]})")

        print("== RUN/STOP + RESTORE (NMI)")
        machine.command(f"KEYS {c64_keys.mask(['STOP']):x}")
        machine.command("RUN 2")
        machine.command("RESTORE 1")
        machine.command("RUN 2")
        machine.command("RESTORE 0")
        machine.command("RUN 4")
        machine.command("KEYS 0")
        machine.command("RUN 20")
        lines = machine.screen()
        # The warm start clears the screen, then BASIC prints a carriage return
        # and READY., so the prompt lands on the second row.
        check(lines[1] == "READY." and not lines[0] and not any(lines[2:]),
              "warm start clears the screen to READY.")
    finally:
        machine.close()
    print(f"PASS: original C64 ROM regression ({'NTSC' if NTSC else 'PAL'})")


if __name__ == "__main__":
    main()
