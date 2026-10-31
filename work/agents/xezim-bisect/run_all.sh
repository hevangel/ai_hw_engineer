#!/bin/sh
# Run every experiment in this folder and print one summary line block each.
# Intended to run inside the pinned image:
#   docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace \
#     ai-hw-engineer:latest sh -c 'cd work/agents/xezim-bisect && sh run_all.sh'
set -u
cd "$(dirname "$0")" || exit 1

run() {
    top="$1"
    printf '=== %s\n' "$top"
    xezim --simulate -s "$top" "$top.sv" 2>&1 \
        | grep -E 'errors=|xcount=|RESULT|first mismatch|PASS|Fatal|rror' \
        | tail -6
    printf '\n'
}

run minimal_fail      # primary candidate: DUT-free, mask oracle, 131072 calls
run v_xonly           # axis 8: how many of the failures are x
run v_ignoreargs      # axis 7: function ignores its arguments
run v_static          # axis 3: default (static) function
run v_noif            # axis 4b: no if/else in the loop
run v_count           # axis 4c: int counter accumulator
run v_foreach         # axis 4d: foreach
run v_zerobase        # axis 5: [11:0] port, i = 0..11
run v_asc             # axis 5: [0:11] port
run v_constidx        # axis 5: constant bit index
run v_retm            # axis 6: return m (no ternary, no inversion)
run v_w2              # axis 2: 2-iteration loop, same total call count
run bisect_count      # axis 1: smallest failing call count
