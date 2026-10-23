#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_formal.sh"
sh "$HERE/run_raster_formal.sh"
sh "$HERE/run_sim.sh"
sh "$HERE/run_raster_sim.sh"
sh "$HERE/run_synth.sh"
sh "$HERE/run_raster_synth.sh"
echo 'MOS 6560 register/raster component gates passed; full VIC qualification remains open.'
