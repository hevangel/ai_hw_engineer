#!/bin/sh
set -eu
# Native stack transitions and original microcode share one executable; every
# run_sim invocation checks both with independently sourced tables/traces.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$SCRIPT_DIR/run_sim.sh"
