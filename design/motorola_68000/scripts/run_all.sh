#!/bin/sh
# Work-in-progress verification flow: lint + synthesis today; the
# SingleStepTests vector replay joins when the MOVE group lands
# (harness compiled; scripts/make_68000_vectors.py).
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
echo '=== motorola_68000: lint ==='
mkdir -p ../work/lint 2>/dev/null || true
HERE=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
mkdir -p "$HERE/work/lint"
verilator --lint-only -Wall -Wno-UNUSEDSIGNAL --top-module motorola_68000 \
    "$HERE/src/motorola_68000.sv" > "$HERE/work/lint/rtl.log"
echo '=== motorola_68000: synthesis ==='
sh "$SCRIPT_DIR/run_synth.sh"
echo '=== motorola_68000 WIP flow PASSED (lint + synth) ==='
