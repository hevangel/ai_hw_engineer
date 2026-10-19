#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/fetch_firmware.py
. scripts/sources.sh
mkdir -p work/directed work/bus_sim
verilator --cc --exe --build -j 4 -Wall --top-module apple_iie -GEXTERNAL_CPU=1 --Mdir work/directed $SOURCES "$(pwd)/tb/directed.cpp" >work/directed_build.log 2>&1
work/directed/Vapple_iie
# Only the testbench deliberately leaves observer outputs open and uses task assignments.
verilator --binary --timing -j 4 -Wall -Wno-PINMISSING -Wno-UNUSEDSIGNAL -Wno-BLKSEQ -Wno-PROCASSINIT --top-module tb_top --Mdir work/bus_sim $SOURCES tb/tb_top.sv >work/bus_build.log 2>&1
work/bus_sim/Vtb_top
xezim --simulate --sv2017 --error-exit -s tb_top $SOURCES tb/tb_top.sv --max-time 1000000ns -l work/xezim.log
grep 'PASS IIe xezim/Verilator' work/xezim.log
