#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/third/obj"
echo "=== motorola_6800 third-party suite: assemble hakanrw/mc6800 tests ==="
python3 "$HERE/scripts/assemble_thirdparty.py"
echo "=== motorola_6800 third-party suite: build runner ==="
verilator --binary --timing -Wall -Wno-BLKSEQ -Wno-PROCASSINIT \
    -Wno-UNUSEDSIGNAL -j 4 --top-module tb_thirdparty \
    --Mdir "$HERE/work/third/obj" "$HERE/src/motorola_6800.sv" \
    "$HERE/tb/tb_thirdparty.sv" > "$HERE/work/third/build.log" 2>&1
echo "=== motorola_6800 third-party suite: run + check ==="
python3 "$HERE/scripts/check_thirdparty.py"
echo "MC6800 third-party software regression PASSED"
