#!/usr/bin/env python3
"""Real-software regression for the SNES board.

Every Peter Lemon ROM that ships with the author's reference screenshot is
run on the RTL board until the rendered frame matches that screenshot
(per-channel tolerance for colour-expansion differences). CPU and SPC700
instruction tests also fail at once if the word FAIL appears in their text
layer. Sound demos without a screenshot must produce non-silent S-DSP output.
Expected results come only from the external files.

Usage: test_software.py [--jobs N] [--max-frames N] [name-filter ...]
"""
import argparse
import base64
import json
import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import struct
import subprocess
import sys

SYSTEM = Path(__file__).resolve().parents[1]
ROOT = SYSTEM.parents[1]
ROMS = SYSTEM / "work" / "roms" / "peterlemon"
HEX = SYSTEM / "work" / "roms" / "hex"
IPL = ROOT / "design" / "sony_s_smp" / "work" / "ipl.hex"
sys.path.insert(0, str(SYSTEM / "scripts"))
import screen  # noqa: E402


class Board:
    def __init__(self, rom):
        HEX.mkdir(parents=True, exist_ok=True)
        hexfile = HEX / (rom.stem + ".hex")
        args = subprocess.run([sys.executable, str(SYSTEM / "scripts" / "prepare_rom.py"), str(rom),
                               str(hexfile)], check=True, capture_output=True, text=True).stdout.split()
        self.proc = subprocess.Popen([str(SYSTEM / "work" / "obj" / "Vsnes"), *args, f"+ipl={IPL}"],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True,
                                     cwd=SYSTEM)

    def ask(self, line):
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()
        reply = json.loads(self.proc.stdout.readline())
        if "error" in reply:
            raise RuntimeError(reply["error"])
        return reply

    def close(self):
        try:
            self.proc.stdin.write("QUIT\n")
            self.proc.stdin.flush()
        except BrokenPipeError:
            pass
        self.proc.wait(timeout=30)


def text_layer(board):
    # PeterLemon's tests keep ASCII in the low bytes of the map at VRAM $F800.
    data = bytes.fromhex(board.ask("MEM 2160640 2048")["hex"])[0::2]
    return "\n".join(data[r * 32:(r + 1) * 32].decode("latin-1") for r in range(32))


def run_screen_test(rom, png, max_frames, chunk):
    board = Board(rom)
    best = 1.0
    try:
        frames = 0
        is_cpu_test = "CPUTest" in rom.parts
        if "SPC700" in rom.parts:
            max_frames = max(max_frames, 2400)   # ~1 s SPC700 timer wait per case
        reset_done = False
        last_text = None
        while frames < max_frames:
            state = board.ask(f"FRAMES {chunk}")
            frames = state["frames"]
            if state.get("overrun"):
                return {"result": "FAIL", "why": "S-DSP micro-op overrun", "frames": frames}
            if is_cpu_test:
                text = text_layer(board)
                if "FAIL" in text:
                    return {"result": "FAIL", "why": "test printed FAIL", "frames": frames}
                # CPUMSC asks the operator to press reset after STP.
                if "Please Reset" in text and text == last_text and not reset_done:
                    board.ask("RESET")
                    reset_done = True
                last_text = text
            reply = board.ask("SCREEN")
            diff = screen.compare(reply, png)
            best = min(best, diff)
            if diff == 0.0:
                return {"result": "PASS", "frames": frames}
        out = SYSTEM / "work" / "images" / (rom.stem + ".png")
        out.parent.mkdir(parents=True, exist_ok=True)
        screen.to_image(reply).save(out)
        return {"result": "FAIL", "why": f"best screen difference {best:.4f}", "frames": frames,
                "image": str(out)}
    finally:
        board.close()


def run_audio_test(rom, frames):
    board = Board(rom)
    try:
        board.ask(f"FRAMES {frames}")
        reply = board.ask("AUDIO")
        raw = base64.b64decode(reply["samples"])
        samples = struct.unpack(f"<{len(raw) // 2}h", raw)
        peak = max((abs(s) for s in samples), default=0)
        if peak < 256:
            return {"result": "FAIL", "why": f"silent output (peak {peak})", "frames": frames}
        return {"result": "PASS", "peak": peak, "frames": frames}
    finally:
        board.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument("--max-frames", type=int, default=400)
    parser.add_argument("--chunk", type=int, default=20)
    parser.add_argument("filters", nargs="*")
    args = parser.parse_args()
    if not ROMS.exists():
        subprocess.run([sys.executable, str(SYSTEM / "scripts" / "fetch_roms.py")], check=True)
    jobs = []
    for rom in sorted(ROMS.rglob("*.sfc")):
        name = str(rom.relative_to(ROMS))
        if args.filters and not any(f in name for f in args.filters):
            continue
        png = rom.with_suffix(".png")
        if png.exists():
            jobs.append((name, lambda r=rom, p=png: run_screen_test(r, p, args.max_frames, args.chunk)))
        elif name.startswith("SPC700/"):
            jobs.append((name, lambda r=rom: run_audio_test(r, 300)))
    results = {}
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = {name: pool.submit(fn) for name, fn in jobs}
        for name, future in futures.items():
            try:
                results[name] = future.result()
            except Exception as error:  # report and continue with the rest
                results[name] = {"result": "FAIL", "why": f"harness error: {error}"}
            r = results[name]
            print(f"{r['result']:4} {name} ({r.get('frames', '-')} frames) {r.get('why', '')}", flush=True)
    (SYSTEM / "work" / "software_results.json").write_text(json.dumps(results, indent=1))
    passed = sum(r["result"] == "PASS" for r in results.values())
    print(f"{passed}/{len(results)} passed")
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
