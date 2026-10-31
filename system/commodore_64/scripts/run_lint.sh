#!/bin/sh
# Verilator -Wall lint of the whole C64 board and every chip on it.
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
. "$SYSTEM/scripts/sources.sh"
for variant in 0 1; do
    verilator --lint-only -Wall -GVARIANT="$variant" --top-module c64_board $C64_SOURCES
    echo "Lint OK (VARIANT=$variant)"
done
