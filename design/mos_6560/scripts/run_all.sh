#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_formal.sh"
sh "$HERE/run_sim.sh"
sh "$HERE/run_synth.sh"
echo 'MOS 6560 register component gates passed; full VIC qualification remains open.'
