#!/bin/sh
# Complete SONY S-DSP flow: lint, independent-oracle gate, synthesis.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_lint.sh"
sh "$HERE/scripts/run_oracle.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'SONY S-DSP ALL PASS'
