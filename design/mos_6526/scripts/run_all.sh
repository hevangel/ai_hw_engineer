#!/bin/sh
# Sampled digital gates. Physical revision/software sign-off remains open.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sh "$HERE/scripts/run_timer_all.sh"
sh "$HERE/scripts/run_tod_all.sh"
sh "$HERE/scripts/run_serial_all.sh"
sh "$HERE/scripts/run_irq_all.sh"
sh "$HERE/scripts/run_formal.sh"
sh "$HERE/scripts/run_sim.sh"
sh "$HERE/scripts/run_software.sh"
sh "$HERE/scripts/run_software.sh" 0
sh "$HERE/scripts/run_transactor.sh"
sh "$HERE/scripts/run_serial_software.sh"
sh "$HERE/scripts/run_tod_software.sh"
sh "$HERE/scripts/run_synth.sh"
echo 'MOS 6526 SAMPLED DIGITAL GATES PASS (external software and revision qualification remain)'
