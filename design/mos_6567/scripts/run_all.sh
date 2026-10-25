#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$HERE/run_vicii_formal.sh"
sh "$HERE/run_vicii_sim.sh"
sh "$HERE/run_vicii_mutants.sh"
sh "$HERE/run_vicii_synth.sh"
echo 'MOS 6567 VIC-II digital gates passed; original C64 software and physical qualification remain open.'
