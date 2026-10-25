#!/usr/bin/env python3
"""Real-software regression: the original Taito Space Invaders ROM runs on
the RTL board. Three gates:

1. Exact independent-oracle checkpoint: at instruction 30 000 (mid boot,
   before the ROM's first EI, so interrupt timing is irrelevant), CPU
   state, shift register and the full 0000h-3FFFh memory image must match
   the superzazu-emulator board twin byte for byte.
2. Attract mode: run with interrupts; the ROM reaches the attract/splash
   loop, both ISRs serve, VRAM is drawn, watchdog never fires.
3. Play: coin, one-player start, autofire — a game runs and the score
   (BCD in work RAM) rises. The oracle plays the same script and must also
   score, proving an independent model agrees on the playable behavior.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SIM = ROOT / "work/obj/Vspace_invaders"
ORACLE = ROOT / "work/oracle_board"
ROM = ROOT / "work/si_rom.hex"


class Simulator:
    def __init__(self):
        self.process = subprocess.Popen(
            [str(SIM), f"+rom={ROM}"],
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


def run_cycles(sim, total, burst=500_000):
    while True:
        state = sim.command(f"RUN {burst}")
        if state["cycles"] >= total or state["halted"] or state["fault"]:
            return state


def main():
    if not ROM.exists():
        raise SystemExit("run scripts/fetch_roms.py first")

    # ---- Gate 1: exact oracle checkpoint at an instruction boundary.
    sim = Simulator()
    try:
        frozen = sim.command("RUNI 30000")
        rtl = sim.command("CHECKPOINT")
    finally:
        sim.close()
    assert frozen["instructions"] == 30000, frozen["instructions"]
    oracle = json.loads(subprocess.run(
        [str(ORACLE), "checkpoint", str(ROM), "30000"],
        capture_output=True, text=True, check=True).stdout)
    for field in ("pc", "sp", "a", "b", "c", "d", "e", "h", "l", "flags",
                  "shift", "shiftOff"):
        if rtl[field] != oracle[field]:
            raise AssertionError(
                f"oracle checkpoint mismatch: {field} RTL={rtl[field]:#x} "
                f"oracle={oracle[field]:#x}")
    if rtl["image"] != oracle["image"]:
        first = next(i // 2 for i in range(0, len(rtl["image"]), 2)
                     if rtl["image"][i:i + 2] != oracle["image"][i:i + 2])
        raise AssertionError(
            f"oracle checkpoint memory mismatch at {first:#06x}: "
            f"RTL={rtl['image'][2*first:2*first+2]} "
            f"oracle={oracle['image'][2*first:2*first+2]}")
    print(f"oracle checkpoint exact at instruction 30000 "
          f"(pc={rtl['pc']:#06x}, memory image {len(rtl['image'])//2} bytes)")

    # ---- Gates 2 and 3 on one machine instance.
    sim = Simulator()
    try:
        sim.command("RESET")
        sim.command("RUNSW 1")
        state = run_cycles(sim, 12_000_000)
        if state["fault"]:
            raise AssertionError("CPU fault during attract")
        if state["halted"]:
            raise AssertionError("CPU halted during attract")
        if state["watchdogResets"]:
            raise AssertionError(f"watchdog fired {state['watchdogResets']} times")
        if state["interrupts"] < 2 * state["frames"] - 20:
            raise AssertionError(f"interrupts={state['interrupts']} for "
                                 f"frames={state['frames']}")
        if int(state["vram"], 16) == 0:
            raise AssertionError("VRAM empty after attract")
        # Pixel-level gate (see failure_notes/2026-10-23-spaceinvaders-
        # vram-bit-order.md): decode the score header through the ROM's own
        # character generator. DrawScoreHead prints MessageScore (28
        # character numbers at ROM 1AE4h) as one-byte-wide font glyphs from
        # the 1E00h table. DrawSimpSprite leaves HL advanced by 8 rows
        # (8x32), so consecutive characters sit 0x100 apart starting at
        # VRAM 241Eh; each glyph is 8 game rows deep (stride 32). This
        # gates the actual rendered pixels, not just byte equality between
        # two implementations.
        rom_bytes = bytes.fromhex("".join(ROM.read_text().split()))
        vram = bytes.fromhex(state["vram"])
        mismatches = []
        for i in range(28):
            char_code = rom_bytes[0x1AE4 + i]
            glyph = rom_bytes[0x1E00 + char_code * 8: 0x1E00 + char_code * 8 + 8]
            for k in range(8):
                addr = 0x241E + i * 0x100 + 32 * k
                if vram[addr - 0x2400] != glyph[k]:
                    mismatches.append((hex(addr), i, k))
        if mismatches:
            raise AssertionError(f"attract score header does not decode "
                                 f"through the ROM font: {mismatches[:4]}")
        print(f"attract mode: {state['frames']} frames, "
              f"{state['interrupts']} interrupts, {state['instructions']} instructions, "
              "score header glyphs decoded through the ROM font")

        # Coin -> credit (BCD at 20EBh). The debounce logic counts on the
        # press-then-release sequence.
        sim.command("IN1 1")
        run_cycles(sim, state["cycles"] + 300_000)
        state = sim.command("IN1 0")
        state = run_cycles(sim, state["cycles"] + 600_000)
        if state["credit"] != 0x01:
            raise AssertionError(f"coin did not add credit (20EB={state['credit']:#04x})")
        print("coin accepted: CREDIT 01")

        # One-player start.
        sim.command("IN1 4")
        state = run_cycles(sim, state["cycles"] + 300_000)
        sim.command("IN1 0")
        state = run_cycles(sim, state["cycles"] + 1_500_000)
        if state["watchdogResets"]:
            raise AssertionError("watchdog fired during game start")
        print(f"game started (pc={state['pc']:#06x})")

        # Fire while sweeping the ship right: stationary fire only chews
        # the player's own shields, so a real sweep is required to reach
        # the rack through the gaps.
        score0 = state["scoreHi"] * 100 + state["scoreLo"] // 16 * 10 + state["scoreLo"] % 16
        end = state["cycles"] + 25_000_000
        shots = 0
        while state["cycles"] < end:
            sim.command("IN1 80")   # right + fire
            state = run_cycles(sim, state["cycles"] + 100_000)
            sim.command("IN1 64")   # right, fire released
            state = run_cycles(sim, state["cycles"] + 100_000)
            shots += 1
            if state["scoreHi"] or state["scoreLo"]:
                break
        score = state["scoreHi"] * 100 + state["scoreLo"] // 16 * 10 + state["scoreLo"] % 16
        if score <= score0:
            raise AssertionError(f"score did not rise while firing "
                                 f"({score0} -> {score}) after {shots} shots")
        if state["watchdogResets"]:
            raise AssertionError("watchdog fired during play")
        print(f"play: score {score0} -> {score} after {shots} shots")
    finally:
        sim.close()

    # ---- The independent oracle plays the same script.
    played = json.loads(subprocess.run(
        [str(ORACLE), "play", str(ROM)],
        capture_output=True, text=True, check=True).stdout)
    if played["credit"] != 0x00:
        print(f"oracle play: credit={played['credit']:#04x} "
              f"(spent on start) score={played['score']}")
    if played["score"] <= 0:
        raise AssertionError(f"oracle did not score while playing "
                             f"(score={played['score']})")
    print("PASS: original Space Invaders ROM boots, attracts, and plays on "
          "the RTL board with exact oracle agreement")
    return 0


if __name__ == "__main__":
    sys.exit(main())
