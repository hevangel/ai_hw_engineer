#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_formal.sh"
sh "$HERE/run_raster_formal.sh"
sh "$HERE/run_video_formal.sh"
sh "$HERE/run_sim.sh"
sh "$HERE/run_raster_sim.sh"
sh "$HERE/run_vic_sim.sh"
sh "$HERE/run_vic_mutants.sh"
sh "$HERE/run_vic20_software.sh"
sh "$HERE/run_synth.sh"
sh "$HERE/run_raster_synth.sh"
sh "$HERE/run_vic_synth.sh"
echo 'MOS 6560 register, raster and complete digital VIC gates passed; original-software and physical qualification remain open.'
