#!/bin/sh
# Lockstep simulation of the RTL against the reference model
# (scripts/upi42_iss.py, written from the Intel UPI-41A manual), plus the
# IBM 1503033 firmware. Usage: run_sim.sh [RANDOM_SEEDS]
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${INTEL_8042_WORK_DIR:-$ROOT/work}
SEEDS=${1:-32}
PY=${PYTHON:-python3}
mkdir -p "$WORK/directed" "$WORK/random" "$WORK/firmware" "$WORK/fw"

echo "== build lockstep bench"
verilator --cc --exe --build -O2 --x-assign 0 --x-initial 0 --public-flat-rw \
    -Wno-fatal --top-module upi42_core -Mdir "$WORK/obj_lockstep" \
    "$ROOT/src/upi42_core.sv" "$ROOT/tb/lockstep_tb.cpp" -o lockstep_tb \
    >"$WORK/build.log" 2>&1 || { tail -20 "$WORK/build.log"; exit 1; }
TB=$WORK/obj_lockstep/lockstep_tb

lockstep() {   # ROM SCRIPT NAME
    "$TB" "$1" "$2" "$WORK/$3.rtl"
    "$PY" "$ROOT/scripts/upi42_trace.py" "$1" "$2" "$WORK/$3.iss" \
        --compare "$WORK/$3.rtl"
}

echo "== firmware: rebuild IBM 1503033 from the pinned listing"
ROM=$("$PY" "$ROOT/scripts/rebuild_1503033.py" --work "$WORK")
echo "== decoder vs independent disassembly"
"$PY" "$ROOT/scripts/check_decoder_vs_listing.py" "$WORK"

echo "== directed tests (model vs manual)"
"$PY" "$ROOT/scripts/directed_tests.py" "$WORK/directed"
echo "== directed tests (RTL vs model)"
for t in "$WORK"/directed/*.bin; do
    n=$(basename "$t" .bin)
    printf '%-26s ' "$n"
    lockstep "$t" "$WORK/directed/$n.txt" "directed/$n"
done

echo "== random programs ($SEEDS seeds)"
s=1
while [ "$s" -le "$SEEDS" ]; do
    "$PY" "$ROOT/scripts/gen_random_test.py" "$s" "$WORK/random/r$s" 20000
    printf 'seed %-3s ' "$s"
    lockstep "$WORK/random/r$s.bin" "$WORK/random/r$s.txt" "random/r$s"
    s=$((s + 1))
done

echo "== IBM 1503033 partial rebuild: AAh self-test"
lockstep "$ROM" "$ROOT/tb/scripts/fw_selftest.txt" fw/selftest
if grep -q '^H' "$WORK/fw/selftest.rtl"; then
    echo "FAIL: self-test replied although its ROM CRC cannot pass"; exit 1
fi
tail -1 "$WORK/fw/selftest.rtl" | grep -q ' pc04F .* sts48 ' || {
    echo "FAIL: expected the ROM-checksum failure loop (pc 04F, status 48)"; exit 1; }
echo "PASS: self-test stops at the ROM checksum stage (status 48h), as the gaps require"

echo "== IBM 1503033 CRC-balanced TEST image: BIOS command sequence"
"$PY" "$ROOT/scripts/make_crc_test_image.py" "$ROM" \
    "$WORK/firmware/1503033_known.json" "$WORK/firmware/1503033_crctest.bin"
lockstep "$WORK/firmware/1503033_crctest.bin" "$ROOT/tb/scripts/fw_bios_cmds.txt" fw/bios_cmds
got=$(awk '$1=="H"{printf "%s ", substr($4,2)}' "$WORK/fw/bios_cmds.rtl")
want="55 00 FF 5D CF CF FE 55 "
[ "$got" = "$want" ] || { echo "FAIL: replies '$got', expected '$want'"; exit 1; }
echo "PASS: replies $got"
echo "PASS: simulation"
