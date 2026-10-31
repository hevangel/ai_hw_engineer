#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/synth"
yosys -Q -T -p "read_verilog -sv -I$ROOT/design/intel_8087/src \
 $ROOT/design/intel_8086_8088/intel_8086/src/*.sv $ROOT/design/intel_8087/src/*.sv \
 $ROOT/design/intel_8259/src/*.sv $ROOT/design/intel_8253_8254/src/*.sv \
 $ROOT/design/intel_8255/src/*.sv $ROOT/design/intel_8237/src/*.sv \
 $ROOT/design/intel_8272/src/intel_8272.sv $ROOT/system/ibm_pc/src/ibm_pc_bus.sv \
 $SYSTEM/src/*.sv; hierarchy -check -top ibm_pc_xt_5160; proc; opt; check -assert; stat; \
 write_json $SYSTEM/work/synth/ibm_pc_xt_5160.json" > "$SYSTEM/work/synth/yosys.log" 2>&1
echo 'PASS XT/8087/fixed-disk hierarchy, word-level synthesis and structural checks'
