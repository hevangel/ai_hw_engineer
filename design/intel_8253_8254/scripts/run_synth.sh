#!/bin/sh
# Run deterministic generic synthesis for both parameter variants.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="$DESIGN_DIR/work/synth"
RTL="$DESIGN_DIR/src/intel_8253_8254.sv"

mkdir -p "$WORK_DIR"

run_variant() {
    variant_name=$1
    parameter_value=$2
    synth_script="$WORK_DIR/${variant_name}.ys"
    log_file="$WORK_DIR/${variant_name}.log"

    cat > "$synth_script" <<EOF
read_verilog -sv $RTL
chparam -set IS_8254 $parameter_value intel_8253_8254
hierarchy -check -top intel_8253_8254
proc
flatten
opt -full
fsm
memory
opt -full
techmap
opt -full
check
stat
write_verilog -noattr $WORK_DIR/${variant_name}_synth.v
write_json $WORK_DIR/${variant_name}_synth.json
EOF

    echo "=== Yosys generic synthesis: $variant_name ==="
    yosys -Q -s "$synth_script" -l "$log_file"
    grep -q "Found and reported 0 problems" "$log_file"
    grep -q "Number of cells:" "$log_file"
}

run_variant intel_8253 0
run_variant intel_8254 1

echo "=== Synthesis passed for both variants ==="
