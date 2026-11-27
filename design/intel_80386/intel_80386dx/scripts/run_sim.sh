#!/bin/sh
# Simulation entry point: the physical-capture replay (see run_vectors.sh).
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec sh "$SCRIPT_DIR/run_vectors.sh" "$@"
