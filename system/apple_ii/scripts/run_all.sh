#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/run_sim.sh
sh ../../design/apple_ii_chips/scripts/run_all.sh
sh ../../design/apple_ii_chips/scripts/run_synth.sh
sh scripts/run_lint.sh
SIMULATOR=iverilog sh scripts/run_board_sim.sh
sh scripts/run_peripheral_sim.sh
sh scripts/run_video_sim.sh
# Mandatory historical software gate: run actual original Monitor commands.
sh scripts/run_reference_boot.sh
sh scripts/run_cassette_sim.sh
echo 'Regressions passed; exact analog reconstruction and authored CPU sign-off remain incomplete.'
exit 1
