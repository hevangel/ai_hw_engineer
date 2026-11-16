#!/bin/sh
# IBM VGA simulation: the Verilator lockstep bench against the reference
# model (scripts/vga_model.py, written from the IBM documents).
# Usage: run_sim.sh [RANDOM_SEEDS] [OPS_PER_SEED]
# Environment: VGA_SRC overrides the RTL directory (run_mutation.sh),
# VGA_WORK_DIR the work directory, VGA_NO_COVERAGE_GATE skips the gate,
# VGA_SKIP_BIOS skips the BIOS stages, VGA_ONLY=name runs one directed test.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKROOT=${VGA_WORK_DIR:-$ROOT/work}
WORK=$WORKROOT/sim
SRC=${VGA_SRC:-$ROOT/src}
SEEDS=${1:-32}
OPS=${2:-600}
PY=${PYTHON:-python3}
S=$ROOT/scripts
FW=$ROOT/work/firmware
mkdir -p "$WORK/directed" "$WORK/random" "$WORK/bios"

echo "== ROM: fetch and verify the IBM PS/2 Display Adapter BIOS"
"$PY" -I "$S/get_rom.py" "$ROOT/work" | tail -1

echo "== build lockstep bench"
verilator --cc --exe --build -O2 -j 4 --x-assign 0 --x-initial 0 -Wno-fatal \
    --top-module ibm_vga -GROM_FILE="\"$FW/vga_rom.hex\"" -Mdir "$WORK/obj" \
    "$SRC/vga_plane_ram.sv" "$SRC/vga_rom.sv" "$SRC/vga_io_decode.sv" \
    "$SRC/vga_general_regs.sv" "$SRC/vga_sequencer.sv" "$SRC/vga_crtc.sv" \
    "$SRC/vga_graphics_ctrl.sv" "$SRC/vga_display_fetch.sv" \
    "$SRC/vga_attribute_ctrl.sv" "$SRC/vga_dac.sv" "$SRC/ibm_vga.sv" \
    "$ROOT/tb/vga_tb.cpp" -o vga_tb \
    >"$WORK/build.log" 2>&1 || { tail -30 "$WORK/build.log"; exit 1; }

lockstep() {   # SCRIPT OUTBASE -> model meets expectations, RTL trace equal
    "$PY" -I "$S/vga_model.py" "$1" "$2.model" --rom "$FW/vga_rom.bin" --coverage "$2.cov"
    "$WORK/obj/vga_tb" "$1" "$2.rtl"
    if ! cmp -s "$2.model" "$2.rtl"; then
        echo "FAIL: RTL differs from model: $2"
        diff "$2.model" "$2.rtl" | head -10
        exit 1
    fi
}

echo "== directed tests (expected values from the IBM documents; RTL vs model)"
"$PY" -I "$S/directed_tests.py" "$WORK/directed"
n=0
while read -r name; do
    if [ -n "${VGA_ONLY:-}" ] && [ "$name" != "$VGA_ONLY" ]; then continue; fi
    lockstep "$WORK/directed/$name.txt" "$WORK/directed/$name"
    n=$((n + 1))
done <"$WORK/directed/list.txt"
echo "PASS: $n directed tests (model meets every expectation; RTL trace identical)"
[ -n "${VGA_ONLY:-}" ] && exit 0

echo "== random sequences ($SEEDS seeds x $OPS operations)"
s=1
lines=0
dots=0
while [ "$s" -le "$SEEDS" ]; do
    "$PY" -I "$S/gen_random_test.py" "$s" "$WORK/random/r$s.txt" "$OPS"
    lockstep "$WORK/random/r$s.txt" "$WORK/random/r$s"
    lines=$((lines + $(wc -l <"$WORK/random/r$s.rtl")))
    d=$(awk '$1 == "T" {n += $3} END {print n + 0}' "$WORK/random/r$s.rtl")
    dots=$((dots + d))
    s=$((s + 1))
done
echo "PASS: $SEEDS seeds identical ($lines trace lines, $dots dots compared)"

if [ -z "${VGA_SKIP_BIOS:-}" ]; then
    echo "== BIOS VIDEO_PARMS geometry (every display entry; RTL vs model; IBM timing)"
    "$PY" -I "$S/bios_modes.py" gen "$FW/vga_rom.bin" "$WORK/bios"
    while read -r name; do
        lockstep "$WORK/bios/$name.txt" "$WORK/bios/$name"
    done <"$WORK/bios/list.txt"
    "$PY" -I "$S/bios_modes.py" check "$FW/vga_rom.bin" "$WORK/bios"
    echo "== ROM static I/O audit"
    "$PY" -I "$S/rom_io_audit.py" "$FW/ibm_vga.bin" "$WORK/bios/io_audit.md" | tail -1
    echo "== ROM execution (Unicorn): POST and INT 10h mode sets, replayed on RTL and model"
    "$PY" -I "$S/rom_exec.py" gen "$FW/vga_rom.bin" "$WORK/bios"
    while read -r name; do
        lockstep "$WORK/bios/$name.txt" "$WORK/bios/$name"
        "$PY" -I "$S/rom_exec.py" check "$FW/vga_rom.bin" "$WORK/bios/$name"
    done <"$WORK/bios/exec_list.txt"
fi

if [ -z "${VGA_SKIP_RATIO:-}" ]; then
echo "== clock-enable ratio: clk at 29.0 and 47.3 MHz, oscillator enables from phase accumulators"
# The card needs clk >= the fastest selected oscillator (one enable per clk
# at most) and no fixed ratio: rerun runs whose model traces exist with
# irregular enables; every trace must equal the model's unchanged.
nr=0
for mhz in 29.0 47.3; do
    for f in "$WORK"/directed/*.model "$WORK"/random/r1.model "$WORK"/random/r2.model              "$WORK"/bios/entry07.model "$WORK"/bios/entry18.model "$WORK"/bios/entry1b.model              "$WORK"/bios/entry1c.model "$WORK"/bios/exec_mode13.model; do
        [ -f "$f" ] || continue
        b=${f%.model}
        VGA_CLK_MHZ=$mhz "$WORK/obj/vga_tb" "$b.txt" "$b.ratio"
        if ! cmp -s "$b.model" "$b.ratio"; then
            echo "FAIL: clk $mhz MHz: RTL differs from model: $b"
            diff "$b.model" "$b.ratio" | head -6
            exit 1
        fi
        nr=$((nr + 1))
    done
done
echo "PASS: $nr runs identical with irregular oscillator enables"
fi

echo "== coverage gate (directed + random + BIOS runs, model counters)"
if [ -n "${VGA_NO_COVERAGE_GATE:-}" ]; then
    "$PY" -I "$S/report_coverage.py" "$WORK"/random/*.cov "$WORK"/directed/*.cov | tail -1
elif [ -n "${VGA_SKIP_BIOS:-}" ]; then
    "$PY" -I "$S/report_coverage.py" "$WORK"/random/*.cov "$WORK"/directed/*.cov --require
else
    "$PY" -I "$S/report_coverage.py" "$WORK"/random/*.cov "$WORK"/directed/*.cov \
        "$WORK"/bios/*.cov --bios-dir "$WORK/bios" --require
fi
echo "PASS: simulation"
