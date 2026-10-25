#!/bin/sh
# Build the persistent Altair 8800 RTL simulator.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/obj"
# --public-flat-rw exposes core internals to the Surfer waveform viewer; it
# makes Verilator partition the verified core's task-based retire writes into
# separate processes, so the resulting MULTIDRIVEN notice is suppressed here.
# The core itself is verified by design/intel_8080/scripts/run_all.sh.
verilator --cc --exe --build -j 4 --assert -Wno-MULTIDRIVEN --public-flat-rw --trace-fst --trace-depth 2 \
    --top-module altair_8800 --Mdir "$SYSTEM/work/obj" \
    "$ROOT/design/intel_8080/src/intel_8080.sv" \
    "$ROOT/design/intel_8080/src/intel_8080_alu.sv" \
    "$SYSTEM/src/altair_8800.sv" \
    "$SYSTEM/src/altair_ram.sv" \
    "$SYSTEM/host/simulator.cpp" > "$SYSTEM/work/build.log" 2>&1
echo "Built $SYSTEM/work/obj/Valtair_8800"
