#!/bin/bash
# Run synthesis with Yosys
# Usage: ./run_synth.sh [target]
# Targets: generic, ice40, ecp5, xilinx

set -e

CHIP_NAME=$(basename $(dirname $(dirname $(realpath $0))))
DESIGN_DIR=$(dirname $(dirname $(realpath $0)))
WORK_DIR=$DESIGN_DIR/work/synth
TARGET=${1:-generic}

# Create work directory
mkdir -p $WORK_DIR

echo "=== Running synthesis: $CHIP_NAME (target: $TARGET) ==="

# Collect source files
SRC_FILES=$(find $DESIGN_DIR/src -name "*.sv" -o -name "*.v" | sort)

# Generate Yosys script
SYNTH_SCRIPT=$WORK_DIR/synth_${TARGET}.ys

cat > $SYNTH_SCRIPT << EOF
# Auto-generated synthesis script for $CHIP_NAME
# Target: $TARGET

# Read design files
EOF

for f in $SRC_FILES; do
    echo "read_verilog -sv $f" >> $SYNTH_SCRIPT
done

cat >> $SYNTH_SCRIPT << EOF

# Elaborate
hierarchy -top ${CHIP_NAME} -check

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
write_verilog -noattr $WORK_DIR/${CHIP_NAME}_synth.v
write_json $WORK_DIR/${CHIP_NAME}_synth.json
EOF
        ;;
    ice40)
        echo "synth_ice40 -top ${CHIP_NAME} -json $WORK_DIR/${CHIP_NAME}_ice40.json" >> $SYNTH_SCRIPT
        ;;
    ecp5)
        echo "synth_ecp5 -top ${CHIP_NAME} -json $WORK_DIR/${CHIP_NAME}_ecp5.json" >> $SYNTH_SCRIPT
        ;;
    xilinx)
        cat >> $SYNTH_SCRIPT << EOF
synth_xilinx -top ${CHIP_NAME}
write_edif $WORK_DIR/${CHIP_NAME}_xilinx.edif
EOF
        ;;
esac

echo "stat" >> $SYNTH_SCRIPT

# Run Yosys
yosys -s $SYNTH_SCRIPT -l $WORK_DIR/synth_${TARGET}.log

echo "=== Synthesis complete ==="
echo "  Log: $WORK_DIR/synth_${TARGET}.log"
echo "  Script: $SYNTH_SCRIPT"
