#!/bin/sh
# Full native-engine gate, including historical software and independent timing.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$HERE/scripts/fetch_native_tests.py" --opcodes all --per-opcode 0
sh "$HERE/scripts/run_native_formal.sh"
sh "$HERE/scripts/run_native_bus.sh"
sh "$HERE/scripts/run_native_control.sh"
sh "$HERE/scripts/run_native_netlist.sh"
sh "$HERE/scripts/run_native_kim.sh"
sh "$HERE/scripts/run_native_synth.sh"
echo 'NATIVE NMOS ALL GATES PASS'
