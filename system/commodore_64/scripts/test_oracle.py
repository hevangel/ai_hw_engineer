#!/usr/bin/env python3
"""Independent-oracle comparison with unchanged VICE x64sc.

Both machines start from zero-filled DRAM with the same verified ROMs.
VICE runs headless; its monitor stops at checkpoints and dumps registers,
cycle-stamped CPU history and the full 64 KiB RAM image. The RTL simulator
stops at the same PCs. Checked: the cycle and registers at the first six
KERNAL IRQ entries ($FF48) and at the first READY-loop fetch ($E5CD), the
complete RAM image there, and two 8,192-instruction cycle-stamped traces.

With --ntsc (6567R8) the comparison is functional only: the READY-loop
registers and RAM image must match (stack bytes below S excepted), and the
cycle offsets are reported. The NTSC badline-stall timing differs from VICE
by one cycle in some stalls; see report/final_report.md.

usage: test_oracle.py [--ntsc]
"""
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SYSTEM = Path(__file__).resolve().parents[1]
WORK = SYSTEM / "work"
sys.path.insert(0, str(SYSTEM / "scripts"))
from c64sim import C64  # noqa: E402

NTSC = "--ntsc" in sys.argv
IRQS = 6


def run_vice():
    if not shutil.which("x64sc"):
        raise SystemExit("x64sc (VICE) is required for the oracle comparison")
    tmp = Path(tempfile.mkdtemp(prefix="c64-vice-"))
    log = tmp / "monitor.log"
    script = ["break ff48"]
    for i in range(IRQS):
        script += ["x", "r"]
        if i in (1, IRQS - 1):
            script.append("chis 8192")
    script += ["del", "break e5cd", "x", "r", "bank ram", "m 0000 ffff", "quit"]
    (tmp / "commands.txt").write_text("\n".join(script) + "\n")
    command = ["x64sc", "-console", "-default", "-model", "ntsc" if NTSC else "c64",
               "-sounddev", "dummy", "-warp",
               "-raminitstartvalue", "0", "-raminitvalueinvert", "0", "-raminitpatterninvert", "0",
               "-raminitvalueoffset", "0", "-raminitstartrandom", "0", "-raminitrepeatrandom", "0",
               "-raminitrandomchance", "0",
               "-kernal", str(WORK / "kernal.bin"), "-basic", str(WORK / "basic.bin"),
               "-chargen", str(WORK / "chargen.bin"),
               "-moncommands", str(tmp / "commands.txt"), "-monlog", "-monlogname", str(log)]
    subprocess.run(command, env={**os.environ, "HOME": str(tmp)}, stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=300, check=False)
    text = log.read_text().splitlines()
    stops = []  # (pc, a, x, y, sp, stopwatch)
    histories, current = [], None
    ram = bytearray(65536)
    for line in text:
        m = re.match(r"\.;([0-9a-f]{4}) ([0-9a-f]{2}) ([0-9a-f]{2}) ([0-9a-f]{2}) ([0-9a-f]{2}) "
                     r".* (\d+)$", line)
        if m:
            stops.append(tuple(int(m.group(i), 16) for i in range(1, 6)) + (int(m.group(6)),))
            current = None
            continue
        m = re.match(r"\.C:([0-9a-f]{4}) .*A:([0-9a-f]{2}) X:([0-9a-f]{2}) Y:([0-9a-f]{2}) "
                     r"SP:([0-9a-f]{2}) \S+\s+(\d+)$", line)
        if m and line.startswith(".C:") and "- A:" not in line:
            if current is None:
                current = []
                histories.append(current)
            current.append((int(m.group(6)),) + tuple(int(m.group(i), 16) for i in range(1, 6)))
            continue
        m = re.match(r">C:([0-9a-f]{4})\s+((?:[0-9a-f]{2}\s+){16})", line)
        if m:
            address = int(m.group(1), 16)
            ram[address:address + 16] = bytes.fromhex(m.group(2).replace(" ", ""))
    shutil.rmtree(tmp, ignore_errors=True)
    if len(stops) != IRQS + 1 or len(histories) != 2:
        raise SystemExit(f"VICE monitor run incomplete: {len(stops)} stops, {len(histories)} traces")
    return stops, histories, bytes(ram)


def run_rtl(final_cycle):
    variant = 0
    machine = C64(variant=variant, extra=["+raminit=0"])
    stops = []
    try:
        for _ in range(IRQS):
            state = machine.command("UNTILPC ff48")
            stops.append((state["pc"], state["a"], state["x"], state["y"], state["s"], state["cycles"]))
        state = machine.command("UNTILPC e5cd")
        stops.append((state["pc"], state["a"], state["x"], state["y"], state["s"], state["cycles"]))
        checkpoint = machine.command("CHECKPOINT")
    finally:
        machine.close()
    # Second, independent run: cycle-stamped trace of the whole boot.
    trace_path = WORK / f"oracle_trace_v{variant}.txt"
    machine = C64(variant=variant, extra=["+raminit=0"])
    try:
        machine.command(f"TRACE {final_cycle + 8} {trace_path}")
    finally:
        machine.close()
    return stops, trace_path.read_text(), bytes.fromhex(checkpoint["ram"])


def compare_trace(vice, rtl_text):
    rtl = {}
    for line in rtl_text.splitlines():
        cycle, pc, a, x, y, s = line.split()[:6]
        rtl[int(cycle)] = tuple(int(v, 16) for v in (pc, a, x, y, s))
    checked = 0
    for cycle, pc, a, x, y, s in vice:
        if cycle < min(rtl) or cycle > max(rtl):
            continue
        if rtl.get(cycle) != (pc, a, x, y, s):
            raise SystemExit(f"trace mismatch at cycle {cycle}: VICE {pc:04x} A={a:02x} X={x:02x} "
                             f"Y={y:02x} S={s:02x}, RTL {rtl.get(cycle)}")
        checked += 1
    if checked < 7000:
        raise SystemExit(f"trace overlap too small: {checked}")
    return checked


def main_ntsc():
    vice_stops, _, vice_ram = run_vice()
    machine = C64(variant=1, extra=["+raminit=0"])
    try:
        rtl_stops = []
        for _ in range(IRQS):
            state = machine.command("UNTILPC ff48")
            rtl_stops.append(state["cycles"])
        state = machine.command("UNTILPC e5cd")
        checkpoint = machine.command("CHECKPOINT")
    finally:
        machine.close()
    v = vice_stops[-1]
    regs = (checkpoint["pc"], checkpoint["a"], checkpoint["x"], checkpoint["y"], checkpoint["s"])
    if regs != v[:5]:
        raise SystemExit(f"NTSC READY loop registers differ: VICE {v[:5]} RTL {regs}")
    rtl_ram = bytes.fromhex(checkpoint["ram"])
    stack_floor = 0x100 + checkpoint["s"] + 1
    diff = [a for a in range(65536) if vice_ram[a] != rtl_ram[a] and not 0x100 <= a < stack_floor]
    if diff:
        raise SystemExit(f"NTSC RAM differs at {len(diff)} addresses, first ${diff[0]:04X}")
    print(f"  READY loop registers identical; RAM identical except the dead stack "
          f"area $0100-${stack_floor - 1:04X}")
    offsets = [r - vs[5] for r, vs in zip(rtl_stops + [checkpoint["cycles"]], vice_stops)]
    print(f"  cycle offsets RTL-VICE at IRQ 1-{IRQS} and READY: {offsets}")
    print("PASS (functional): RTL C64 (NTSC 6567R8) matches VICE x64sc; timing discrepancy open")


def main():
    if NTSC:
        main_ntsc()
        return
    vice_stops, histories, vice_ram = run_vice()
    rtl_stops, trace, rtl_ram = run_rtl(vice_stops[-1][5])
    names = [f"IRQ {i + 1} ($FF48)" for i in range(IRQS)] + ["READY loop ($E5CD)"]
    for name, v, r in zip(names, vice_stops, rtl_stops):
        if v != r:
            raise SystemExit(f"{name}: VICE pc={v[0]:04x} a={v[1]:02x} x={v[2]:02x} y={v[3]:02x} "
                             f"s={v[4]:02x} cycle={v[5]}; RTL pc={r[0]:04x} a={r[1]:02x} x={r[2]:02x} "
                             f"y={r[3]:02x} s={r[4]:02x} cycle={r[5]}")
        print(f"  {name}: cycle {r[5]}, A={r[1]:02X} X={r[2]:02X} Y={r[3]:02X} S={r[4]:02X} match")
    diff = [a for a in range(65536) if vice_ram[a] != rtl_ram[a]]
    if diff:
        raise SystemExit(f"RAM differs at {len(diff)} addresses, first ${diff[0]:04X}")
    print("  64 KiB RAM image at the READY loop: identical")
    for history in histories:
        checked = compare_trace(history, trace)
        print(f"  cycle-stamped trace {history[0][0]}-{history[-1][0]}: {checked} instructions "
              "identical (PC, A, X, Y, S, cycle)")
    print("PASS: RTL C64 (PAL 6569) matches VICE x64sc cycle for cycle")


if __name__ == "__main__":
    main()
