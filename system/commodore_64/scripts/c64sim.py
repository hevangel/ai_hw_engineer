"""Line-protocol client for the persistent C64 RTL simulator."""
import json
import subprocess
import sys
from pathlib import Path

SYSTEM = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SYSTEM / "host"))
import c64_keys  # noqa: E402


def petscii_screen(codes):
    """Screen codes (upper-case/graphics set) to text lines."""
    def ch(c):
        c &= 0x7f
        if c == 0:
            return "@"
        if 1 <= c <= 26:
            return chr(c + 64)
        if 27 <= c <= 63:
            return "[£]↑←"[c - 27] if c < 32 else chr(c)
        return "?"
    return ["".join(ch(c) for c in codes[r * 40:(r + 1) * 40]).rstrip() for r in range(25)]


class C64:
    def __init__(self, variant=0, extra=()):
        work = SYSTEM / "work"
        self.process = subprocess.Popen(
            [str(work / f"obj_v{variant}" / "Vc64_board"), f"+basic={work / 'basic.hex'}",
             f"+kernal={work / 'kernal.hex'}", f"+chargen={work / 'chargen.hex'}", *extra],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)

    def command(self, line):
        self.process.stdin.write(line + "\n")
        self.process.stdin.flush()
        reply = json.loads(self.process.stdout.readline())
        if "error" in reply:
            raise RuntimeError(reply["error"])
        return reply

    def screen(self, state=None):
        state = state or self.command("STATE")
        return petscii_screen(bytes.fromhex(state["text"]))

    def type(self, text, hold=3, gap=3):
        for char in text:
            self.command(f"KEYS {c64_keys.mask(c64_keys.chord(char)):x}")
            self.command(f"RUN {hold}")
            self.command("KEYS 0")
            self.command(f"RUN {gap}")

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write("QUIT\n")
            self.process.stdin.flush()
            self.process.wait(timeout=10)
