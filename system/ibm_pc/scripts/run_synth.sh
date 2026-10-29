#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/synth"
yosys -Q -l "$SYSTEM/work/synth/ibm_pc.log" -p "read_verilog -sv \
  $ROOT/design/intel_8086_8088/intel_8086/src/*.sv $ROOT/design/intel_8259/src/*.sv \
  $ROOT/design/intel_8253_8254/src/*.sv $ROOT/design/intel_8255/src/*.sv \
  $ROOT/design/intel_8237/src/*.sv $ROOT/design/intel_8272/src/intel_8272.sv \
  $SYSTEM/src/*.sv; hierarchy -check -top ibm_pc; synth -noabc -top ibm_pc; \
  abc -script +strash,map; check -assert; stat; write_json $SYSTEM/work/synth/ibm_pc.json"
echo 'PASS: IBM PC RTL hierarchy synthesis and structural checks'
