#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-}
while [ "$#" -gt 0 ]; do
    case "$1" in
        --work-dir)
            [ "$#" -ge 2 ] || { echo 'Missing value for --work-dir' >&2; exit 2; }
            [ -n "$2" ] || { echo 'Empty value for --work-dir' >&2; exit 2; }
            WORK_DIR=$2
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--work-dir DIR]"
            echo 'DIR must be empty; the INTEL_80286_WORK_DIR environment variable is also supported.'
            echo 'When omitted, a fresh release directory is created under design/intel_80286/work.'
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 [--work-dir DIR]" >&2
            exit 2
            ;;
    esac
done
if [ -z "$WORK_DIR" ]; then
    mkdir -p "$DESIGN_DIR/work"
    WORK_DIR=$(mktemp -d "$DESIGN_DIR/work/release.XXXXXX")
else
    mkdir -p "$WORK_DIR"
    WORK_DIR=$(CDPATH= cd -- "$WORK_DIR" && pwd)
    if [ -n "$(find "$WORK_DIR" -mindepth 1 -print -quit)" ]; then
        echo "Refusing to reuse non-empty evidence directory: $WORK_DIR" >&2
        exit 2
    fi
fi
export INTEL_80286_WORK_DIR="$WORK_DIR"
python3 "$SCRIPT_DIR/preflight.py"
python3 -m unittest discover -s "$SCRIPT_DIR" -p 'test_preflight.py'
python3 -m unittest discover -s "$SCRIPT_DIR" -p 'test_audit_formal.py'
python3 -m unittest discover -s "$SCRIPT_DIR" -p 'test_build_runner.py'
python3 -m unittest discover -s "$SCRIPT_DIR" -p 'test_work_paths.py'
mkdir -p "$WORK_DIR/lint" "$WORK_DIR/formal_runs"
FORMAL_WORK_DIR=$(mktemp -d "$WORK_DIR/formal_runs/release.XXXXXX")
export FORMAL_WORK_DIR
RUN_STAMP=$(date -u +%Y%m%dT%H%M%SZ)
PROTECTED_MODE_RUN_NAME="protected_mode_release_${RUN_STAMP}"
export PROTECTED_MODE_RUN_NAME
echo '=== Intel 80286 strict lint ==='
verilator --lint-only -Wall --top-module intel_80286 "$DESIGN_DIR/src/"*.sv > "$WORK_DIR/lint/rtl.log" 2>&1
sh "$SCRIPT_DIR/run_formal.sh"
sh "$SCRIPT_DIR/run_bus_owner.sh"
sh "$SCRIPT_DIR/run_native_bus.sh"
sh "$SCRIPT_DIR/run_native_core.sh"
sh "$SCRIPT_DIR/run_sim.sh"
sh "$SCRIPT_DIR/run_vectors.sh"
sh "$SCRIPT_DIR/run_hardware.sh"
python3 "$SCRIPT_DIR/run_undefined_mutations.py"
python3 "$SCRIPT_DIR/run_protection_mutations.py"
python3 "$SCRIPT_DIR/run_protected_event_mutations.py"
python3 "$SCRIPT_DIR/run_protected_string_mutations.py" \
    "$WORK_DIR/$PROTECTED_MODE_RUN_NAME/build_manifest.json" \
    "protected_string_mutations_release_${RUN_STAMP}"
sh "$SCRIPT_DIR/run_software.sh"
sh "$SCRIPT_DIR/run_synth.sh"
python3 "$SCRIPT_DIR/audit_formal.py" --work-dir "$FORMAL_WORK_DIR" --output "$FORMAL_WORK_DIR/audit.json"
echo '=== Intel 80286 implemented-subset regression PASSED; full CPU remains incomplete ==='
