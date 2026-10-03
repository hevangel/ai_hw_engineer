#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/check_copper_ic_wiring.py
sh scripts/run_sim.sh
sh ../../design/apple_ii_chips/scripts/run_all.sh
sh ../../design/apple_ii_chips/scripts/run_synth.sh
sh scripts/run_lint.sh
SIMULATOR=iverilog sh scripts/run_board_sim.sh
sh scripts/run_floating_bus_sim.sh
sh scripts/run_peripheral_sim.sh
sh scripts/run_output_sim.sh
sh scripts/run_video_sim.sh
# Mandatory historical software gate: run actual original Monitor commands.
sh scripts/run_reference_boot.sh
sh scripts/run_cassette_sim.sh
sh scripts/run_host_test.sh
sh scripts/run_basic_sim.sh
sh scripts/run_authored_boot.sh
sh scripts/run_authored_cassette.sh
sh scripts/run_cassette_command_firmware.sh
sh scripts/run_full_write_board.sh
sh scripts/run_full_read_board.sh
echo 'Regressions passed; exact analog reconstruction and original-dump font comparison remain incomplete.'
exit 1
