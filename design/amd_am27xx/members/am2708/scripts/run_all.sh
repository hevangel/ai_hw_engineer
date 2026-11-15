#!/bin/bash

# Am2708 simulation script
# Run Am2708 functional simulation tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Default simulation parameters
SIMULATOR="iverilog"
SIM_FLAGS="-gSEED=12345 -W all -Wno-timescale"
TESTBENCH="tb/tb_top.sv"
LOG_FILE="sim.log"

# Function to run simulation
run_sim() {
    echo "Running Am2708 simulation..."
    cd "${PROJECT_ROOT}"
    
    # Compile source files
    echo "Compiling RTL..."
    ${SIMULATOR} ${SIM_FLAGS} \
        src/am2708_core.sv \
        tb/tb_am2708_basic.sv \
        tb/tb_am2708_program.sv \
        tb/tb_am2708_erase.sv
    
    # Run test scenarios
    echo "Running basic operations test..."
    ${SIMULATOR} ${SIM_FLAGS} -m ${TESTBENCH} \
        -c "tb_basic_test" \
        > "${LOG_FILE}" 2>&1
    
    echo "Running programming sequence test..."
    ${SIMULATOR} ${SIM_FLAGS} -m ${TESTBENCH} \
        -c "tb_program_test" \
        >> "${LOG_FILE}"  villain >&1
    
    echo "Running erase timing test..."
    ${SIMULATOR} ${SIM_FLAGS} -m ${TESTBENCH} \
        -c "tb_erase_test" \
        >> "${LOG_FILE}" 2>&1
    
    echo "Simulation completed successfully"
}

# Function to run formal verification
run_formal() {
    echo "Running Am2708 formal verification..."
    cd "${PROJECT_ROOT}"
    
    # Check if SymbiYosys is available
    if command -v yosys &> /dev/null; then
        echo "Running formal verification with SymbiYosys..."
        yosys -Q -L formal.log formal/am2708_formal.sby
    else
        echo "Warning: yosys not found. Skipping formal verification."
    fi
}

# Function to run synthesis
run_synth() {
    echo "Running Am2708 synthesis..."
    cd "${PROJECT_ROOT}"
    
    if command -v yosys &> /dev/null; then
        echo "Synthesizing Am2708 RTL..."
        yosys -p "read_verilog src/am2708_core.sv; synth -top am2708_core" \
            > synth.log 2>&1
        
        echo "Synthesis completed successfully"
    else
        echo "Warning: yosys not found. Skipping synthesis."
    fi
}

# Function to generate test vectors
generate_test_vectors() {
    echo "Generating test vectors for Am2708..."
    cd "${SCRIPT_DIR}"
    
    python3 generate_test_vectors.py \
        --output test_vectors.bin \
        --count 1024 \
        --pattern random
}

# Main execution
if [[ "${1:-}" == "sim" ]]; then
    run_sim
elif [[ "${1:-}" == "formal" ]]; then
    run_formal
elif [[ "${1:-}" == "synth" ]]; then
    run_synth
elif [[ "${1:-}" == "vectors" ]]; then
    generate_test_vectors
elif [[ "${1:-}" == "all" ]]; then
    run_sim
    run_formal
    run_synth
    generate_test_vectors
else
    echo "Usage: $0 {sim|formal|synth|vectors|all}"
    echo "  sim      - Run simulation tests"
    echo "  formal   - Run formal verification"
    echo "  synth    - Run synthesis"
    echo "  vectors  - Generate test vectors"
    echo "  all      - Run complete verification pipeline"
    exit 1
fi