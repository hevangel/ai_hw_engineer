#!/bin/bash
# Run synthesis with Yosys
# Usage: ./run_synth.sh [target] [top_module]
# Targets: generic, ice40, ecp5, xilinx
# The top module defaults to intel_4001 and must not be derived from the
# directory name: the design folder may be mounted at any path (e.g. as
# /workspace inside the verification container).

set -e

DESIGN_DIR=$(dirname $(dirname $(realpath $0)))
WORK_DIR=$DESIGN_DIR/work/synth
TARGET=${1:-generic}
TOP_MODULE=${2:-intel_4001}

# Create work directory
mkdir -p $WORK_DIR

echo "=== Running synthesis: $TOP_MODULE (target: $TARGET) ==="

# Collect source files
SRC_FILES=$(find $DESIGN_DIR/src -name "*.sv" -o -name "*.v" | sort)

# Generate Yosys script
SYNTH_SCRIPT=$WORK_DIR/synth_${TARGET}.ys

cat > $SYNTH_SCRIPT << EOF
# Auto-generated synthesis script for $TOP_MODULE
# Target: $TARGET

# Read design files
EOF

for f in $SRC_FILES; do
    echo "read_verilog -sv $f" >> $SYNTH_SCRIPT
done

cat >> $SYNTH_SCRIPT << EOF

# Elaborate
hierarchy -top ${TOP_MODULE} -check

# Synthesize
proc
flatten
opt -full
fsm
opt
memory
opt

EOF

case $TARGET in
    generic)
        cat >> $SYNTH_SCRIPT << EOF
# Generic synthesis
techmap
opt_clean
stat
write_verilog -noattr $WORK_DIR/${TOP_MODULE}_synth.v
write_json $WORK_DIR/${TOP_MODULE}_synth.json
EOF
        ;;
    ice40)
        echo "synth_ice40 -top ${TOP_MODULE} -json $WORK_DIR/${TOP_MODULE}_ice40.json" >> $SYNTH_SCRIPT
        ;;
    ecp5)
        echo "synth_ecp5 -top ${TOP_MODULE} -json $WORK_DIR/${TOP_MODULE}_ecp5.json" >> $SYNTH_SCRIPT
        ;;
    xilinx)
        cat >> $SYNTH_SCRIPT << EOF
synth_xilinx -top ${TOP_MODULE}
write_edif $WORK_DIR/${TOP_MODULE}_xilinx.edif
EOF
        ;;
esac

echo "stat" >> $SYNTH_SCRIPT

# Run Yosys
yosys -s $SYNTH_SCRIPT -l $WORK_DIR/synth_${TARGET}.log

echo "=== Synthesis complete ==="
echo "  Log: $WORK_DIR/synth_${TARGET}.log"
echo "  Script: $SYNTH_SCRIPT"
