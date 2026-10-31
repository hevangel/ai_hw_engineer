#!/usr/bin/env python3
"""Real-software regression: freely distributed NES test ROMs run on the RTL
board (scripts/fetch_roms.py pins them). Gates:

1. nestest (kevtris) in automation mode from $C000: every instruction's PC,
   A, X, Y, P, S and CPU cycle count must match the published nestest.log
   (8 991 lines, an independent Nintendulator trace), and the ROM's own
   result bytes $02/$03 must read 0.
2. blargg's newer suites report through $6000 (status) / $6001-$6003
   ($DE $B0 $61 signature) / $6004 (text); status 0 is a pass and $81 asks
   for a reset, which the harness performs with the board reset line.
3. blargg's 2005 suites keep their result code in zero page ($F8 for the
   sprite/vbl/branch/PAL-APU runtime, $F0 for the APU and PPU 2005 sets);
   1 means every test in the ROM passed. cpu_timing_test6 only prints, so
   its name-table text (read through the side-effect-free CIRAM peek) must
   show PASSED.

cpu_dummy_reads and sprdma_and_dmc_dma report only on screen/audio (or as a
CRC to compare against hardware by eye) and are not part of the suite.

usage: test_software.py [--only SUBSTRING] [--jobs N] [--list]
"""
import argparse
import json
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROMS = ROOT / "work/roms"
sys.path.insert(0, str(ROOT / "scripts"))
from prepare_rom import prepare  # noqa: E402

# (rom, protocol, frame budget, region, expected)
# expected is "pass" or a documented known failure ("known: reason").
SUITE = [
    ("instr_test-v5/all_instrs.nes", "6000", 3000, 0,
     "known: LXA #imm ($AB) magic constant varies between chips; the core uses $EE "
     "(SingleStepTests nes6502), blargg expects $FF"),
    ("instr_test-v5/official_only.nes", "6000", 3000, 0, "pass"),
    ("instr_timing/instr_timing.nes", "6000", 1500, 0, "pass"),
    ("instr_misc/instr_misc.nes", "6000", 600, 0, "pass"),
    ("cpu_interrupts_v2/cpu_interrupts.nes", "6000", 900, 0, "pass"),
    ("cpu_dummy_writes/cpu_dummy_writes_oam.nes", "6000", 900, 0, "pass"),
    ("cpu_dummy_writes/cpu_dummy_writes_ppumem.nes", "6000", 900, 0, "pass"),
    ("cpu_exec_space/test_cpu_exec_space_ppuio.nes", "6000", 600, 0, "pass"),
    ("cpu_exec_space/test_cpu_exec_space_apu.nes", "6000", 900, 0, "pass"),
    ("cpu_reset/registers.nes", "6000", 600, 0, "pass"),
    ("cpu_reset/ram_after_reset.nes", "6000", 600, 0, "pass"),
    ("apu_test/apu_test.nes", "6000", 1500, 0, "pass"),
    ("apu_reset/4015_cleared.nes", "6000", 600, 0, "pass"),
    ("apu_reset/4017_timing.nes", "6000", 600, 0, "pass"),
    ("apu_reset/4017_written.nes", "6000", 600, 0, "pass"),
    ("apu_reset/irq_flag_cleared.nes", "6000", 600, 0, "pass"),
    ("apu_reset/len_ctrs_enabled.nes", "6000", 600, 0, "pass"),
    ("apu_reset/works_immediately.nes", "6000", 600, 0, "pass"),
    ("ppu_vbl_nmi/ppu_vbl_nmi.nes", "6000", 3000, 0, "pass"),
    ("oam_read/oam_read.nes", "6000", 600, 0, "pass"),
    ("oam_stress/oam_stress.nes", "6000", 1800, 0, "pass"),
    ("ppu_open_bus/ppu_open_bus.nes", "6000", 600, 0, "pass"),
    ("cpu_timing_test6/cpu_timing_test.nes", "screen", 1500, 0, "pass"),
    ("branch_timing_tests/1.Branch_Basics.nes", "f8", 300, 0, "pass"),
    ("branch_timing_tests/2.Backward_Branch.nes", "f8", 300, 0, "pass"),
    ("branch_timing_tests/3.Forward_Branch.nes", "f8", 300, 0, "pass"),
] + [
    (f"blargg_apu_2005.07.30/{name}.nes", "f0", 600, 0, "pass") for name in (
        "01.len_ctr", "02.len_table", "03.irq_flag", "04.clock_jitter",
        "05.len_timing_mode0", "06.len_timing_mode1", "07.irq_flag_timing",
        "08.irq_timing", "09.reset_timing", "10.len_halt_timing",
        "11.len_reload_timing")
] + [
    (f"pal_apu_tests/{name}.nes", "f8", 600, 1, "pass") for name in (
        "01.len_ctr", "02.len_table", "03.irq_flag", "04.clock_jitter",
        "05.len_timing_mode0", "06.len_timing_mode1", "07.irq_flag_timing",
        "08.irq_timing", "10.len_halt_timing", "11.len_reload_timing")
] + [
    (f"blargg_ppu_tests_2005.09.15b/{name}.nes", "f0", 600, 0, "pass") for name in (
        "palette_ram", "sprite_ram", "vbl_clear_time", "vram_access")
] + [
    ("blargg_ppu_tests_2005.09.15b/power_up_palette.nes", "f0", 300, 0,
     "known: compares palette RAM at power-up with the values of the author's own "
     "console (\"probably unique to my NES\"); the model powers up with zeros"),
] + [
    (f"vbl_nmi_timing/{name}.nes", "f8", 900, 0, "pass") for name in (
        "1.frame_basics", "2.vbl_timing", "3.even_odd_frames", "4.vbl_clear_timing",
        "5.nmi_suppression", "6.nmi_disable", "7.nmi_timing")
] + [
    (f"sprite_hit_tests_2005.10.05/{name}.nes", "f8", 600, 0, "pass") for name in (
        "01.basics", "02.alignment", "03.corners", "04.flip", "05.left_clip",
        "06.right_edge", "07.screen_bottom", "08.double_height", "09.timing_basics",
        "10.timing_order", "11.edge_timing")
] + [
    (f"sprite_overflow_tests/{name}.nes", "f8", 600, 0, "pass") for name in (
        "1.Basics", "2.Details", "3.Timing", "4.Obscure", "5.Emulator")
]


class Simulator:
    def __init__(self, args, region=0):
        binary = ROOT / ("work/obj_pal/Vnes" if region else "work/obj/Vnes")
        self.process = subprocess.Popen(
            [str(binary), *args], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            text=True, bufsize=1)

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

    def mem(self, addr, length):
        return bytes.fromhex(self.command(f"MEM {addr} {length}")["hex"])

    def close(self):
        if self.process.poll() is None:
            self.process.stdin.write("QUIT\n")
            self.process.stdin.flush()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()


def rom_args(rom, entry=None):
    stem = re.sub(r"[^A-Za-z0-9]+", "_", rom)
    return prepare(ROMS / rom, ROOT / "work/images" / stem, entry)["args"]


def nestest():
    log = (ROMS / "other/nestest.log").read_text().splitlines()
    sim = Simulator(rom_args("other/nestest.nes", 0xC000))
    try:
        trace = sim.command(f"TRACE {len(log)}")["trace"]
        result = sim.mem(2, 2)
    finally:
        sim.close()
    if len(trace) != len(log):
        raise AssertionError(f"nestest: trace stopped after {len(trace)} instructions")
    base = trace[0][6] - 7
    for number, (line, row) in enumerate(zip(log, trace), 1):
        m = re.match(r"([0-9A-F]{4}).*A:([0-9A-F]{2}) X:([0-9A-F]{2}) Y:([0-9A-F]{2}) "
                     r"P:([0-9A-F]{2}) SP:([0-9A-F]{2}).*CYC:(\d+)", line)
        want = [int(m[i], 16) for i in range(1, 7)] + [int(m[7])]
        got = row[:6] + [row[6] - base]
        if want != got:
            raise AssertionError(f"nestest.log line {number} mismatch:\n  log: {line}\n"
                                 f"  rtl: PC={got[0]:04X} A={got[1]:02X} X={got[2]:02X} "
                                 f"Y={got[3]:02X} P={got[4]:02X} SP={got[5]:02X} CYC={got[6]}")
    if result != b"\0\0":
        raise AssertionError(f"nestest result bytes $02/$03 = {result.hex()}")
    return f"{len(log)} instructions match nestest.log (registers and cycle counts)"


def run_6000(sim, budget):
    frames = 0
    reset_at = None
    while frames < budget:
        state = sim.command("FRAMES 10")
        frames += 10
        if state["jammed"] or state["fault"]:
            return False, f"CPU stopped at PC=${state['pc']:04X}"
        status = sim.mem(0x6000, 4)
        if status[1:] != b"\xde\xb0\x61":
            continue
        if status[0] == 0x81:
            if reset_at is None:
                reset_at = frames
            elif frames - reset_at >= 10:
                sim.command("RESET")
                reset_at = None
            continue
        reset_at = None
        if status[0] < 0x80:
            text = sim.mem(0x6004, 1024).split(b"\0")[0].decode("ascii", "replace")
            text = " / ".join(t.strip() for t in text.splitlines() if t.strip())
            return status[0] == 0, f"code {status[0]} after {frames} frames: {text}"
    return False, f"no final status within {budget} frames"


def screen_text(sim):
    table = sim.mem(0x2000, 2048)
    return " / ".join(
        "".join(chr(b) if 32 <= b < 127 else " " for b in table[r * 32:r * 32 + 32]).strip()
        for r in range(64) if any(32 < b < 127 for b in table[r * 32:r * 32 + 32]))


def run_screen(sim, budget):
    frames = 0
    while frames < budget:
        state = sim.command("FRAMES 30")
        frames += 30
        if state["jammed"] or state["fault"]:
            return False, f"CPU stopped at PC=${state['pc']:04X}"
        text = screen_text(sim)
        if "PASSED" in text:
            return True, f"PASSED on screen after {frames} frames"
        if "FAIL" in text:
            return False, text
    return False, f"no result on screen within {budget} frames"


def run_zp(sim, budget, addr):
    frames = 0
    code = 0
    while frames < budget:
        state = sim.command("FRAMES 10")
        frames += 10
        if state["jammed"] or state["fault"]:
            return False, f"CPU stopped at PC=${state['pc']:04X}"
        code = sim.mem(addr, 1)[0]
        if code == 1:
            return True, f"result 1 after {frames} frames"
    return False, f"result code {code} after {budget} frames"


def run_rom(entry):
    rom, protocol, budget, region, expected = entry
    sim = Simulator(rom_args(rom), region)
    try:
        if protocol == "6000":
            ok, detail = run_6000(sim, budget)
        elif protocol == "screen":
            ok, detail = run_screen(sim, budget)
        else:
            ok, detail = run_zp(sim, budget, 0xF0 if protocol == "f0" else 0xF8)
    except (RuntimeError, ValueError) as error:
        ok, detail = False, str(error)
    finally:
        sim.close()
    return rom, region, ok, detail, expected


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", default="")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--list", action="store_true")
    options = parser.parse_args()
    suite = [e for e in SUITE if options.only in e[0]]
    if options.list:
        print("\n".join(e[0] for e in suite))
        return
    if not (ROMS / "manifest.json").exists():
        raise SystemExit("run scripts/fetch_roms.py first")
    failures = 0
    if "nestest" in "other/nestest.nes" and options.only in "other/nestest.nes":
        print(f"PASS nestest: {nestest()}", flush=True)
    with ThreadPoolExecutor(options.jobs) as pool:
        for rom, region, ok, detail, expected in pool.map(run_rom, suite):
            tag = "PAL " if region else ""
            if ok:
                print(f"PASS {tag}{rom}: {detail}", flush=True)
            elif expected.startswith("known"):
                print(f"KNOWN {tag}{rom}: {detail} ({expected})", flush=True)
            else:
                failures += 1
                print(f"FAIL {tag}{rom}: {detail}", flush=True)
    total = len(suite)
    if failures:
        raise SystemExit(f"{failures} of {total} test ROMs failed")
    print(f"PASS: nestest and {total} test ROMs")


if __name__ == "__main__":
    main()
