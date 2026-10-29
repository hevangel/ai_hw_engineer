#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator --lint-only -Wall --top-module commodore_906114 "$HERE/src/commodore_906114.sv"
echo 'COMMODORE 906114 LINT PASS'
