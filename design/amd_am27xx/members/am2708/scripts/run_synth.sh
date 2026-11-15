#!/bin/bash

# Am2708 synthesis script
# Run Am2708 RTL synthesis using Yosys

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Default synthesis parameters
SYNTH_TOOL="yosys"
TOP_MODULE="am2708_core"
OUTPUT_DIR="synth"
LOG_FILE="synth.log"

# Function to run synthesis
run_synthesis() {
    echo "Running Am2708 synthesis..."
    cd "${PROJECT_ROOT}"
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    
    # Check if Yosys is available
    if command -v ${SYNTH_TOOL} &> /dev/null; then
        echo "Synthesizing ${TOP_MODULE} with ${SYNTH_TOOL}..."
        
        # Run synthesis with basic optimizations
        ${SYNTH_TOOL} -p \
            "read_verilog src/am2708_core.sv; \
             hierarchy -top ${TOP_MODULE}; \
             proc; \
             opt; \
             memory; \
             techmap; \
             opt; \
             check; \
             write_verilog ${OUTPUT_DIR}/${TOP_MODULE}_mapped.v"
        
        if [[ $? -eq 0 ]]; then
            echo "Synthesis completed successfully"
            echo "Output written to ${OUTPUT_DIR}/${TOP_MODULE}_mapped.v"
        else
            echo "Error: Synthesis failed"
            exit 1
        fi
        
        # Generate synthesis statistics
        ${SYNTH_TOOL} -p \
            "read_verilog src/am2708_core.sv; \
             hierarchy -top ${TOP_MODULE}; \
             stat; \
             show" > "${OUTPUT_DIR}/stats.log" 2>&1
        
        echo "Synthesis statistics written to ${OUTPUT_DIR}/stats.log"
    else
(head -1)$
        echo "Warning: ${SYNTH_TOOL} not found. Skipping synthesis."
        echo "Please install Yosys or equivalent synthesis tool."
    fi
}

# Function to run Yosys logging synthesis
run_synthesis_with_logging() {
    echo "Running Am2708 synthesis with detailed logging..."
    cd "${PROJECT_ROOT}"
    
    mkdir -p "${OUTPUT_DIR}"
    
    if command -v ${SYNTH_TOOL} &> /dev/null; then
        # Run synthesis with detailed logging
        ${SYNTH_TOOL} -v -p \
            "read_verilog src/am2708_core.sv; \
             hierarchy -top ${TOP_MODULE}; \
             proc; \
             opt; \
             memory; \
             techmap; \
             opt; \
             check; \
             write_verilog ${OUTPUT_DIR}/${TOP_MODULE}_mapped.v" \
            >> "${LOG_FILE}" 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo "Synthesis with logging completed successfully"
            echo "Log written to ${LOG_FILE}"
        else
            echo "Error: Synthesis with logging failed"
            exit 1
        fi
    else
        echo "Warning: ${SYNTH_TOOL} not found. Skipping synthesis with logging."
    fi
}

# Function to generate synthesis report
generate_synthesis_report() {
    echo "Generating synthesis report..."
    cd "${PROJECT_ROOT}"
    
    mkdir -p "${OUTPUT_DIR}"
    
    if [[ -f "${OUTPUT_DIR}/${TOP_MODULE}_mapped.v" ]]; then
        echo "Synthesis report for ${TOP_MODULE}:"
        echo "===================================="
        echo "Mapped Verilog file: ${OUTPUT_DIR}/${TOP_MODULE}_mapped.v"
        echo "Statistics log: ${OUTPUT_DIR}/stats.log"
        
        if [[ -f "${OUTPUT_DIR}/stats.log" ]]; then
            echo ""
            echo "Synthesis statistics:"
            echo "======================"
            tail -20 "${OUTPUT_DIR}/stats.log"
        fi
    else
        echo "Warning: No mapped Verilog file found. Synthesis may not have completed successfully."
    fi
}

# Function to run synthesis for specific targets
run_synthesis_for_target() {
    local target=$1
    echo "Running synthesis for target: ${target}"
    cd "${PROJECT_ROOT}"
    
    if command -v ${SYNTH_TOOL} &> /dev/null; then
        # Synthesize with target-specific options
        ${SYNTH_TOOL} -p \
            "read_verilog src/am2708_core.sv; \
             hierarchy -top ${TOP_MODULE}; \
             proc; \
             opt; \
             memory; \
             techmap; \
             opt; \
             check; \
             write_verilog ${OUTPUT_DIR}/${TOP_MODULE}_${target}_mapped.v"
        
        if [[ $? -eq 0 ]]; then
            echo "Synthesis for target '${target}' completed successfully"
        else
            echo "Error: Synthesis for target '${target}' failed"
            exit 1
        fi
    else
        echo "Warning: ${SYNTH_TOOL} not found. Skipping synthesis for target."
    fi
}

# Main execution
if [[ "${1:-}" == "logging" ]]; then
    run_synthesis_with_logging
    generate_synthesis_report
elif [[ "${1:-}" == "target" && -n "${2:-}" ]]; then
    run_synthesis_for_target "${2}"
elif [[ "${1:-}" == "basic" || -z "${1:-}" ]]; then
    run_synthesis
    generate_synthesis_report
else
    echo "Usage: $0 {basic|logging|target <target_name>}"
    echo "  basic     - Run basic synthesis"
    echo "  logging   - Run synthesis with detailed logging"
    echo "  target    - Run synthesis for a specific target (requires target name)"
    exit 1
fi