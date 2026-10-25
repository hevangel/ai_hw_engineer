#!/bin/sh
# Build the persistent Space Invaders RTL simulator and the oracle board.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/obj"
# --public-flat-rw exposes core internals to the Surfer waveform viewer; it
# makes Verilator partition the verified core's task-based retire writes
# into separate processes, so the resulting MULTIDRIVEN notice is
# suppressed. The core itself is verified by design/intel_8080's own suite.
verilator --cc --exe --build -j 4 --assert -Wno-MULTIDRIVEN --public-flat-rw --trace-fst --trace-depth 2 \
    --top-module space_invaders --Mdir "$SYSTEM/work/obj" \
    "$ROOT/design/intel_8080/src/intel_8080.sv" \
    "$ROOT/design/intel_8080/src/intel_8080_alu.sv" \
    "$SYSTEM/src/space_invaders.sv" \
    "$SYSTEM/src/si_memory.sv" \
    "$SYSTEM/src/si_shift.sv" \
    "$SYSTEM/host/simulator.cpp" > "$SYSTEM/work/build.log" 2>&1
gcc -O2 -std=c99 -Wall -Wextra \
    -I "$ROOT/design/amd_am9080/references/superzazu" \
    "$SYSTEM/scripts/oracle_board.c" \
    "$ROOT/design/amd_am9080/references/superzazu/i8080.c" \
    -o "$SYSTEM/work/oracle_board" -lm >> "$SYSTEM/work/build.log" 2>&1
echo "Built $SYSTEM/work/obj/Vspace_invaders and $SYSTEM/work/oracle_board"
