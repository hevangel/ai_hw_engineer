#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/run_sim.sh
sh scripts/run_analog_sim.sh
