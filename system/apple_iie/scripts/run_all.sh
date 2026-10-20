#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/run_lint.sh
sh scripts/run_formal.sh
sh scripts/run_sim.sh
sh scripts/run_synth.sh
# Mandatory real software and keyboard-driven board acceptance.
sh scripts/run_firmware.sh
sh scripts/run_coverage.sh
sh scripts/run_xezim_firmware.sh
sh scripts/run_host_test.sh
echo 'PASS Apple IIe functional platform acceptance; analog/disk scope limits are documented'
