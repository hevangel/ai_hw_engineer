#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$ROOT/scripts/run_lint.sh"
sh "$ROOT/scripts/run_formal.sh"
sh "$ROOT/scripts/run_sim.sh"
sh "$ROOT/scripts/run_synth.sh"
echo "Intel 8008 complete flow passed"
