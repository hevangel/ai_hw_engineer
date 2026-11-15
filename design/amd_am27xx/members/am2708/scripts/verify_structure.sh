#!/bin/bash

# Simple test script to verify Am2708 directory structure
# This script checks if all required directories and files are present

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Function to check if directory exists
check_directory() {
    local dir_path=$1
    local description=$2
    
    if [[ -d "${dir_path}" ]]; then
        echo "✓ ${description}: ${dir_path}"
    else
        echo "✗ ${description}: ${dir_path} (missing)"
        return 1
    fi
}

# Function to check if file exists
check_file() {
    local file_path=$1
    local description=$2
    
    if [[ -f "${file_path}" ]]; then
        echo "✓ ${description}: ${file_path}"
    else
        echo "✗ ${description}: ${file_path} (missing)"
        return 1
    fi
}

# Main verification function
verify_structure() {
    echo "Verifying Am2708 directory structure..."
    echo "==========================================="
    
    local errors=0
    
    # Check core directories
    check_directory "${PROJECT_ROOT}/design/amd_am27xx" "Family root directory"
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members" "Members directory"
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members/am2708" "Am2708 member directory"
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/src" "Source directory"
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/tb" "Testbench directory"
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/formal" "Formal verification directory"
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/plans" "Plans directory"
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/scripts" "Scripts directory"
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/report" "Report directory"
    
    # Check critical files
    check_file "${PROJECT_ROOT}/design/amd_am27xx/README.md" "Family README"
    check_file "${PROJECT_ROOT}/design/amd_am27xx/spec/spec.md" "Family specification"
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/README.md" "Am2708 README"
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/spec/spec.md" "Am2708 specification"
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/plans/implementation_plan.md" "Implementation plan"
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/plans/testplan.md" "Test plan"
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/plans/formal_plan.md" "Formal plan"
    
    # Check scripts
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/scripts/run_all.sh" "All-in-one script"
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/scripts/run_formal.sh" "Formal verification script"
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/scripts/run_synth.sh" "Synthesis script"
    
    # Check formal files
    check_file "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/formal/am2708_formal.sby" "Formal verification configuration"
    
    # Check other directories (optional)
    check_directory "${PROJECT_ROOT}/design/amd_am27xx/members/am2708/src" "Source directory" || true
    
    echo ""
    echo "Verification complete."
    echo "Note: This is the initial structure. RTL and testbench files need to be added."
}

# Main execution
if [[ "${1:-}" == "detailed" ]]; then
    echo "Running detailed verification..."
    verify_structure
else
    echo "Usage: $0 {detailed}"
    echo "  detailed - Run detailed structure verification"
    exit 1
fi