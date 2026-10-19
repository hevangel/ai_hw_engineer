#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/fetch_firmware.py
. scripts/sources.sh
xezim --simulate --sv2017 --error-exit -s tb_firmware $SOURCES tb/tb_firmware.sv --max-time 100000000ns -l work/xezim_firmware.log
grep 'PASS xezim original IIe ROM' work/xezim_firmware.log
