#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$SCRIPT_DIR/run_sim.sh" "$@"
echo "Library coverage and proof limits are documented in report/library_report.md"
