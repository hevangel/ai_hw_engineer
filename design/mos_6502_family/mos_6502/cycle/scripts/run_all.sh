#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/run_lint.sh
sh scripts/run_formal.sh
sh scripts/run_sim.sh
sh scripts/run_full_sim.sh
sh scripts/run_pin_sim.sh
sh scripts/run_synth.sh
# Cross-core differential (review item C3): the same program on both 6502
# implementations, with the negative control that proves the check can fail.
sh ../compare/run.sh
sh ../compare/negative_control.sh
# Mandatory real historical software, executed by this authored core.
sh ../../../../system/apple_ii/scripts/run_authored_boot.sh
sh ../../../../system/apple_ii/scripts/run_authored_cassette.sh
echo 'PASS authored NMOS 6502 documented-instruction sign-off'
