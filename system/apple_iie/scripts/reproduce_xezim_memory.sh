#!/bin/sh
# Diagnostic expected to fail on the recorded xezim version; kept outside acceptance.
set -eu
cd "$(dirname "$0")/.."
if test "${SIMULATOR:-xezim}" = verilator;then
    verilator --binary --timing -j 4 -Wall -Wno-PROCASSINIT -Wno-BLKSEQ --top-module tb_memory_observation --Mdir work/memory_observation tb/memory_observation.sv tb/tb_memory_observation.sv >work/memory_observation_build.log 2>&1
    work/memory_observation/Vtb_memory_observation >work/memory_observation_verilator.log 2>&1
    grep 'PASS asynchronous memory' work/memory_observation_verilator.log
else
    xezim --simulate --sv2017 --error-exit -s tb_memory_observation tb/memory_observation.sv tb/tb_memory_observation.sv --max-time 100ns -l work/memory_observation_xezim.log
    grep 'PASS asynchronous memory' work/memory_observation_xezim.log
fi
