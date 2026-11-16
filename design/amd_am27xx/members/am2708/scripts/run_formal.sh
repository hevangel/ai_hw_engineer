# Am2708 formal verification script
# Controls formal verification using SymbiYosys

#!/bin/bash

# Am2708 formal verification script
# Run formal verification for Am2708 implementation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Default formal verification parameters
FORMAL_TOOL="yosys"
FORMAL_SCRIPT="formal.am2708"
LOG_FILE="formal.log"
TIMEOUT=300  # seconds

# Function to run formal verification
run_formal() {
    echo "Running Am2708 formal verification..."
    cd "${PROJECT_ROOT}"
    
    # Check if SymbiYosys/SMT solver is available
    if command -v yosys &> /dev/null; then
        echo "Using SymbiYosys for formal verification..."
        
        # Run formal verification with timeout
        timeout ${TIMEOUT} ${FORMAL_TOOL} -Q -L "${LOG_FILE}" \
            formal/${FORMAL_SCRIPT}.sby
        
        if [[ $? -eq 0 ]]; then
            echo "Formal verification completed successfully"
        elif [[ $? -eq 124 ]]; then
            echo "Error: Formal verification timed out after ${TIMEOUT} seconds"
            exit 1
        else
            echo "Error: Formal verification failed"
            exit 1
        fi
    else
        echo "Warning: ${FORMAL_TOOL} not found. Skipping formal verification."
        echo "Please install SymbiYosys or equivalent formal verification tool."
    fi
}

# Function to run specific formal tasks
run_formal_task() {
    local task_name=$1
    echo "Running formal task: ${task_name}"
    cd "${PROJECT_ROOT}"
    
    if command -v yosys &> /dev/null; then
        yosys -Q -L "${LOG_FILE}" formal/${FORMAL_SCRIPT}.${task_name}.sby
        
        if [[ $? -eq 0 ]]; then
            echo "Formal task '${task_name}' completed successfully"
        else
            echo "Error: Formal task '${task_name}' failed"
            exit 1
        fi
    else
        echo "Warning: ${FORMAL_TOOL} not found. Skipping formal task."
    fi
}

# Function to analyze formal results
analyze_formal_results() {
    echo "Analyzing formal verification results..."
    cd "${PROJECT_ROOT}"
    
    if [[ -f "${LOG_FILE}" ]]; then
        echo "Formal verification log summary:"
        echo "===================================="
        tail -50 "${LOG_FILE}"
        
        # Check for errors in the log
        if grep -q "ERROR" "${LOG_FILE}"; then
            echo "WARNING: Errors found in formal verification log"
        fi
        
        if grep -q "COVER" "${LOG_FILE}"; then
            echo "Coverage information available in log"
        fi
    else
        echo "Warning: Formal log file not found"
    fi
}

# Function to run BMC (Bounded Model Checking)
run_bmc() {
    echo "Running BMC for Am2708..."
    run_formal_task "bmc"
}

# Function to run prove (Theorem Proving)
run_prove() {
    echo "Running PROVE for Am2708..."
    run_formal_task "prove"
}

# Function to run cover (Coverage analysis)
run_cover() {
    echo "Running COVER for Am2708..."
    run_formal_task "cover"
}

# Main execution
if [[ "${1:-}" == "bmc" ]]; then
    run_bmc
    analyze_formal_results
elif [[ "${1:-}" == "prove" ]]; then
    run_prove
    analyze_formal_results
elif [[ "${1:-}" == "cover" ]]; then
    run_cover
    analyze_formal_results
elif [[ "${1:-}" == "all" ]]; then
    run_formal
    analyze_formal_results
else
    echo "Usage: $0 {bmc|prove|cover|all}"
    echo "  bmc     - Run BMC (Bounded Model Checking)"
    echo "  prove   - Run PROVE (Theorem Proving)"
    echo "  cover   - Run COVER (Coverage analysis)"
    echo "  all     - Run complete formal verification suite"
    exit 1
fi