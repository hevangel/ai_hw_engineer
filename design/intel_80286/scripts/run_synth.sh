#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
mkdir -p "$WORK_DIR/synth"
yosys -Q -l "$WORK_DIR/synth/intel_80286.log" -p "read_verilog -sv $DESIGN_DIR/src/*.sv; hierarchy -check -top intel_80286; synth -top intel_80286; check -assert; stat; write_json $WORK_DIR/synth/intel_80286.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_native_beats.log" -p "read_verilog -sv $DESIGN_DIR/src/*.sv; chparam -set NATIVE_BEATS 1 intel_80286; hierarchy -check -top intel_80286; synth -top intel_80286; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_native_beats.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_event_control.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_event_control.sv; synth -top intel_80286_event_control; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_event_control.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_segment_check.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_segment_check.sv; synth -top intel_80286_segment_check; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_segment_check.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_segment_load.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_segment_check.sv $DESIGN_DIR/src/intel_80286_segment_load.sv; synth -top intel_80286_segment_load; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_segment_load.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_code_check.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_code_check.sv; synth -top intel_80286_code_check; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_code_check.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_code_load.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_code_check.sv $DESIGN_DIR/src/intel_80286_code_load.sv; synth -top intel_80286_code_load; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_code_load.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_access_check.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_access_check.sv; synth -top intel_80286_access_check; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_access_check.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_cached_reference.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_access_check.sv $DESIGN_DIR/src/intel_80286_cached_reference.sv; hierarchy -check -top intel_80286_cached_reference; synth -top intel_80286_cached_reference; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_cached_reference.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_native_bus.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_native_bus.sv; hierarchy -check -top intel_80286_native_bus; synth -top intel_80286_native_bus; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_native_bus.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_82288.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_82288.sv; hierarchy -check -top intel_80286_82288; synth -top intel_80286_82288; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_82288.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_82c284_reset.log" -p "read_verilog -sv $DESIGN_DIR/src/intel_80286_82c284_reset.sv; hierarchy -check -top intel_80286_82c284_reset; synth -top intel_80286_82c284_reset; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_82c284_reset.json"
yosys -Q -l "$WORK_DIR/synth/intel_80286_native_cpu.log" -p "read_verilog -sv $DESIGN_DIR/src/*.sv; hierarchy -check -top intel_80286_native_cpu; synth -top intel_80286_native_cpu; check -assert; stat; write_json $WORK_DIR/synth/intel_80286_native_cpu.json"
