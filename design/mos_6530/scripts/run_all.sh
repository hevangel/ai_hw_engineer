#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
python3 "$HERE/make_roms.py" --check
sh "$HERE/run_lint.sh"
sh "$HERE/run_formal.sh"
sh "$HERE/run_sim.sh"
sh "$HERE/run_synth.sh"
echo '=== MOS 6530 complete sampled flow passed ==='
