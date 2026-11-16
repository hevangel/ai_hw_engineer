#!/bin/sh
# IBM EGA simulation: the Verilator lockstep bench against the reference
# model (scripts/ega_model.py, written from the IBM technical reference).
# Usage: run_sim.sh [RANDOM_SEEDS] [OPS_PER_SEED]
# Environment: EGA_SRC overrides the RTL directory (used by run_mutation.sh),
# EGA_WORK_DIR the work directory, EGA_NO_COVERAGE_GATE skips the gate,
# EGA_SKIP_BIOS skips the BIOS geometry/replay stage.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORKROOT=${EGA_WORK_DIR:-$ROOT/work}
WORK=$WORKROOT/sim
SRC=${EGA_SRC:-$ROOT/src}
SEEDS=${1:-32}
OPS=${2:-600}
PY=${PYTHON:-python3}
S=$ROOT/scripts
FW=$ROOT/work/firmware
mkdir -p "$WORK/directed" "$WORK/random" "$WORK/bios"

echo "== ROM: fetch and verify IBM 6277356"
"$PY" "$S/get_rom.py" "$ROOT/work" | tail -1

echo "== build lockstep bench"
verilator --cc --exe --build -O2 -j 4 --x-assign 0 --x-initial 0 -Wno-fatal \
    --top-module ibm_ega -GROM_FILE="\"$FW/ega_u44_chip.hex\"" -Mdir "$WORK/obj" \
    "$SRC/ega_plane_ram.sv" "$SRC/ega_rom.sv" "$SRC/ega_io_decode.sv" \
    "$SRC/ega_ext_regs.sv" "$SRC/ega_sequencer.sv" "$SRC/ega_crtc.sv" \
    "$SRC/ega_graphics_ctrl.sv" "$SRC/ega_display_fetch.sv" \
    "$SRC/ega_attribute_ctrl.sv" "$SRC/ibm_ega.sv" "$ROOT/tb/ega_tb.cpp" -o ega_tb \
    >"$WORK/build.log" 2>&1 || { tail -30 "$WORK/build.log"; exit 1; }

lockstep() {   # SCRIPT OUTBASE -> model meets expectations, RTL trace equal
    "$PY" "$S/ega_model.py" "$1" "$2.model" --rom "$FW/ega_u44.bin" --coverage "$2.cov"
    "$WORK/obj/ega_tb" "$1" "$2.rtl"
    if ! cmp -s "$2.model" "$2.rtl"; then
        echo "FAIL: RTL differs from model: $2"
        diff "$2.model" "$2.rtl" | head -10
        exit 1
    fi
}

echo "== directed tests (expected values from the TR; RTL vs model)"
"$PY" "$S/directed_tests.py" "$WORK/directed"
n=0
while read -r name; do
    lockstep "$WORK/directed/$name.txt" "$WORK/directed/$name"
    n=$((n + 1))
done <"$WORK/directed/list.txt"
echo "PASS: $n directed tests (model meets every expectation; RTL trace identical)"

echo "== random sequences ($SEEDS seeds x $OPS operations)"
s=1
lines=0
dots=0
while [ "$s" -le "$SEEDS" ]; do
    "$PY" "$S/gen_random_test.py" "$s" "$WORK/random/r$s.txt" "$OPS"
    lockstep "$WORK/random/r$s.txt" "$WORK/random/r$s"
    lines=$((lines + $(wc -l <"$WORK/random/r$s.rtl")))
    d=$(awk '$1 == "T" {n += $3} END {print n + 0}' "$WORK/random/r$s.rtl")
    dots=$((dots + d))
    s=$((s + 1))
done
echo "PASS: $SEEDS seeds identical ($lines trace lines, $dots dots compared)"

if [ -z "${EGA_SKIP_BIOS:-}" ]; then
    echo "== BIOS VIDEO_PARMS geometry (every table entry; RTL vs model; IBM rates)"
    "$PY" "$S/bios_modes.py" gen "$FW/ega_u44.bin" "$WORK/bios"
    while read -r name; do
        lockstep "$WORK/bios/$name.txt" "$WORK/bios/$name"
    done <"$WORK/bios/list.txt"
    "$PY" "$S/bios_modes.py" check "$FW/ega_u44.bin" "$WORK/bios"
    echo "== BIOS initialization and font-load replay"
    "$PY" "$S/bios_replay.py" gen "$FW/ega_u44.bin" "$WORK/bios"
    for name in replay_mode3 replay_mode3_enh replay_mode7; do
        lockstep "$WORK/bios/$name.txt" "$WORK/bios/$name"
        "$PY" "$S/bios_replay.py" check "$FW/ega_u44.bin" "$WORK/bios/$name"
    done
fi

echo "== coverage gate (directed + random + BIOS runs, model counters)"
if [ -n "${EGA_NO_COVERAGE_GATE:-}" ]; then
    "$PY" "$S/report_coverage.py" "$WORK"/random/*.cov "$WORK"/directed/*.cov | tail -1
elif [ -n "${EGA_SKIP_BIOS:-}" ]; then
    "$PY" "$S/report_coverage.py" "$WORK"/random/*.cov "$WORK"/directed/*.cov --require
else
    "$PY" "$S/report_coverage.py" "$WORK"/random/*.cov "$WORK"/directed/*.cov         "$WORK"/bios/*.cov --bios-dir "$WORK/bios" --require
fi
echo "PASS: simulation"
