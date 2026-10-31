#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
python3 "$SCRIPT_DIR/preflight.py"
# Each invocation owns a fresh evidence directory. Never overwrite a prior PASS.
mkdir -p "$WORK_DIR/formal_runs"
if [ -z "${FORMAL_WORK_DIR:-}" ]; then
    FORMAL_WORK_DIR=$(mktemp -d "$WORK_DIR/formal_runs/run.XXXXXX")
fi
mkdir -p "$FORMAL_WORK_DIR"
FORMAL_WORK_DIR=$(CDPATH= cd -- "$FORMAL_WORK_DIR" && pwd)
echo "Formal evidence directory: $FORMAL_WORK_DIR"
cd "$DESIGN_DIR/formal"
# Run selected configs when passed; otherwise run components, the core, and
# the optional full-core PDR job last so a long proof cannot mask component
# and bounded-core results.
run_config() {
    config=$1
    [ -f "$config" ] || { echo "Missing formal configuration: $config" >&2; exit 1; }
    design=${config%.sby}
    tasks=$(awk '
        /^\[tasks\][[:space:]]*$/ { in_tasks = 1; next }
        /^\[/ { if (in_tasks) exit }
        in_tasks {
            sub(/#.*/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            if ($0 != "") print $0
        }
    ' "$config")
    [ -n "$tasks" ] || { echo "Missing task list: $config" >&2; exit 1; }
    for task in $tasks; do
        echo "=== Intel 80286 formal: $design $task ==="
        sby -d "$FORMAL_WORK_DIR/${design}_$task" "$config" "$task"
    done
}

if [ "$#" -gt 0 ]; then
    for config in "$@"; do
        run_config "$config"
    done
else
    for config in intel_80286_*.sby; do
        [ -f "$config" ] || { echo "Missing formal configurations" >&2; exit 1; }
        [ "$config" = intel_80286_pdr.sby ] && continue
        run_config "$config"
    done
    run_config intel_80286.sby
    if [ -f intel_80286_pdr.sby ]; then
        run_config intel_80286_pdr.sby
    fi
fi
