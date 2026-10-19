#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/fetch_firmware.py
. scripts/sources.sh
yosys -Q -T -p "read_verilog -DSYNTHESIS -sv $SOURCES; hierarchy -check -top apple_iie; proc; opt; memory -nomap; opt; check -assert; stat; write_json work/apple_iie.json" >work/synthesis.log 2>&1 || { tail -50 work/synthesis.log;exit 1; }
echo 'PASS IIe synthesis/check with inferred main/aux RAM and ROM (no technology mapping)'
