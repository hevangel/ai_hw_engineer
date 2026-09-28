#!/bin/sh
# Run the complete Intel 4004 verification and synthesis flow.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

echo "=== Intel 4004 complete flow ==="
sh "$SCRIPT_DIR/run_lint.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_formal.sh" all
sh "$SCRIPT_DIR/run_synth.sh"
echo "=== Authentic Busicom firmware: all 42 manual examples ==="
BUSICOM_BACKEND="${BUSICOM_BACKEND:-verilator}" \
    sh "$SCRIPT_DIR/../../../system/busicom_141pf/scripts/run_manual_test.sh" --profile recovered-rom
echo "=== Intel 4004 complete flow passed ==="
