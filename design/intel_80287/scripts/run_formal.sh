#!/bin/sh
# Controller proofs (BMC, induction, two covers) with VARIANT=1.
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$D/work"
cd "$D/formal"
status=0
for mode in bmc prove cover_stack cover_bus; do
    if sby -f -d "$D/work/formal_$mode" intel_80287_control.sby "$mode" > "$D/work/formal_$mode.log" 2>&1
    then echo "PASS $mode"; else echo "FAIL $mode"; status=1; fi
done
exit $status
