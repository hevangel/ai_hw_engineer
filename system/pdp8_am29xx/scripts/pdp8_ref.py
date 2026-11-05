"""Independent PDP-8 reference model (architectural instruction-set simulator).

This is a test oracle, not the implementation.  It is written from external
artifacts only:

  * R. M. Supnik, SIMH ``PDP8/pdp8_cpu.c`` (MIT licence), fetched from
    https://raw.githubusercontent.com/simh/simh/master/PDP8/pdp8_cpu.c and
    stored with its copyright notice in ``work/ref/pdp8_cpu.c``.  Instruction
    decode, effective-address formation, auto-indexing, the defer state, the
    operate micro-operation order and the interrupt-last behaviour follow that
    source.
  * D. W. Jones, "PDP-8 Microcoded Instructions"
    (https://homepage.divms.uiowa.edu/~jones/pdp8/man/micro.html) for the
    group-one micro-operation order (CLA, CLL, CMA, CML, IAC, then rotate) and
    for the fact that byte swap is a PDP-8/E feature, absent on this profile.
  * The 1966 PDP-8 handbook order of combined group-one operations, restated
    in "PDP-8 Computer and Teletype ASR-33 Programming Info": CLA/CLL,
    CMA/CML, IAC, then the rotates.

The model deliberately does not look at the RTL.  Its purpose is to catch
shared misreadings between the RTL and itself; where the two disagree, an
external source decides.

Machine profile: 1965 PDP-8 ("straight-8"), 4096 words, no EAE, no memory
extension, no byte swap, no user mode.
"""

from __future__ import annotations

import argparse
import pathlib

WORD_MASK = 0o7777
MEM_SIZE = 4096


class PDP8:
    def __init__(self, memory: dict[int, int] | None = None) -> None:
        self.mem = [0] * MEM_SIZE
        if memory:
            for address, value in memory.items():
                self.mem[address & (MEM_SIZE - 1)] = value & WORD_MASK
        self.pc = 0
        self.ac = 0
        self.link = 0
        self.sr = 0          # front-panel switch register
        self.halted = False
        self.instructions = 0

    # ------------------------------------------------------------------ state
    def state(self) -> tuple[int, int, int]:
        return (self.pc, self.ac, self.link)

    # --------------------------------------------------------------- execute
    def step(self) -> str:
        """Execute one instruction.  Returns 'run', 'halt' or 'illegal'."""
        if self.halted:
            return "halt"
        instruction_address = self.pc
        ir = self.mem[self.pc]
        self.pc = (self.pc + 1) & WORD_MASK
        self.instructions += 1
        opcode = (ir >> 9) & 0o7

        if opcode <= 0o5:
            if ir & 0o200:                     # current page
                ea = (instruction_address & 0o7600) | (ir & 0o177)
            else:                              # page zero
                ea = ir & 0o177
            if ir & 0o400:                     # indirect
                pointer = ea
                if (pointer & 0o7770) == 0o010:
                    # Auto-index locations 0010-0017: increment, then use the
                    # incremented value as the address.
                    self.mem[pointer] = (self.mem[pointer] + 1) & WORD_MASK
                    ea = self.mem[pointer]
                else:
                    ea = self.mem[pointer]

            if opcode == 0o0:                  # AND
                self.ac &= self.mem[ea]
            elif opcode == 0o1:                # TAD
                total = ((self.link << 12) | self.ac) + self.mem[ea]
                self.link = (total >> 12) & 1
                self.ac = total & WORD_MASK
            elif opcode == 0o2:                # ISZ
                self.mem[ea] = (self.mem[ea] + 1) & WORD_MASK
                if self.mem[ea] == 0:
                    self.pc = (self.pc + 1) & WORD_MASK
            elif opcode == 0o3:                # DCA
                self.mem[ea] = self.ac
                self.ac = 0
            elif opcode == 0o4:                # JMS
                self.mem[ea] = self.pc
                self.pc = (ea + 1) & WORD_MASK
            else:                              # JMP
                self.pc = ea
            return "run"

        if opcode == 0o6:                      # IOT
            return "io"

        # ------------------------------------------------------------- OPR
        if (ir & 0o400) == 0:                  # group 1
            if ir & 0o200:
                self.ac = 0
            if ir & 0o100:
                self.link = 0
            if ir & 0o040:
                self.ac = (~self.ac) & WORD_MASK
            if ir & 0o020:
                self.link ^= 1
            if ir & 0o001:                     # IAC: 13-bit increment
                total = ((self.link << 12) | self.ac) + 1
                self.link = (total >> 12) & 1
                self.ac = total & WORD_MASK
            shift = (ir >> 1) & 0o7
            if shift == 1:
                # Byte swap is a PDP-8/E feature; a straight-8 ignores it.
                pass
            else:
                value = (self.link << 12) | self.ac
                if shift == 2:                 # RAL
                    value = ((value << 1) | (value >> 12)) & 0o17777
                elif shift == 3:               # RTL
                    value = ((value << 2) | (value >> 11)) & 0o17777
                elif shift == 4:               # RAR
                    value = ((value >> 1) | (value << 12)) & 0o17777
                elif shift == 5:               # RTR
                    value = ((value >> 2) | (value << 11)) & 0o17777
                elif shift in (6, 7):
                    # Both rotate bits: undefined on the hardware and excluded
                    # from generated tests; the model leaves the state alone.
                    return "run"
                self.link = (value >> 12) & 1
                self.ac = value & WORD_MASK
            return "run"

        if (ir & 0o001) == 0:                  # group 2
            condition = False
            if ir & 0o020:
                condition = condition or bool(self.link)
            if ir & 0o040:
                condition = condition or (self.ac == 0)
            if ir & 0o100:
                condition = condition or bool(self.ac & 0o4000)
            skip = condition ^ bool(ir & 0o010)
            if skip:
                self.pc = (self.pc + 1) & WORD_MASK
            if ir & 0o200:
                self.ac = 0
            if ir & 0o004:
                self.ac |= self.sr
            if ir & 0o002:
                self.halted = True
                return "halt"
            return "run"

        # Group 3 exists only with the EAE option; this machine has none.
        return "run"


def run_image(memory: dict[int, int], start: int, limit: int = 200000):
    cpu = PDP8(memory)
    cpu.pc = start
    trace = []
    while not cpu.halted and cpu.instructions < limit:
        trace.append(cpu.state())
        reason = cpu.step()
        if reason == "io":
            raise RuntimeError(f"IOT at {cpu.pc - 1:04o} is not modelled here")
        if reason == "halt":
            break
    if cpu.instructions >= limit:
        raise RuntimeError("instruction limit reached")
    return trace, cpu


def load_hex(path: str | pathlib.Path) -> dict[int, int]:
    memory = {}
    for index, line in enumerate(pathlib.Path(path).read_text().splitlines()):
        text = line.split("//")[0].strip()
        if not text or "x" in text.lower():
            continue
        memory[index] = int(text, 16) & WORD_MASK
    return memory


def main() -> int:
    parser = argparse.ArgumentParser(description="Independent PDP-8 ISS")
    parser.add_argument("--image", required=True)
    parser.add_argument("--start", type=lambda text: int(text, 8), default=0)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    memory = load_hex(args.image)
    trace, cpu = run_image(memory, args.start)
    with open(args.out, "w", encoding="utf-8", newline="\n") as handle:
        for pc, ac, link in trace:
            handle.write(f"{pc} {ac} {link}\n")
    print(f"{len(trace)} instructions, final pc={cpu.pc:04o} ac={cpu.ac:04o} l={cpu.link}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
