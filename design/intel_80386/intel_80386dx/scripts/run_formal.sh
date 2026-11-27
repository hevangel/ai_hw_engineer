#!/bin/sh
# Run the SymbiYosys proofs and covers in formal/.
# SBY selects its Yosys through the SBY_YOSYS-style options below; set
# I386_SBY to override the sby command (default: sby, or yowasp-sby).
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
FORMAL_DIR=$(dirname "$SCRIPT_DIR")/formal
SBY=${I386_SBY:-sby}
cd "$FORMAL_DIR"
STATUS=0
for job in intel_80386_divider intel_80386_alu; do
    echo "=== SBY $job ==="
    if "$SBY" -f "$job.sby"; then echo "PASS: $job"; else echo "FAIL: $job"; STATUS=1; fi
done
exit $STATUS
