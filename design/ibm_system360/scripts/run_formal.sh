#!/bin/sh
# Run the SymbiYosys formal jobs for the S/360 M1 core.
#
# Usage: ./run_formal.sh [all|bmc|prove|cover]
#   all    - every job and every task it defines (default)
#   bmc|prove|cover - that task for every job that defines it
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
FORMAL_DIR="$HERE/formal"
WORK_DIR="$HERE/work/formal"
TASK=${1:-all}

mkdir -p "$WORK_DIR"

# The core job has no induction task: k-induction does not converge on this
# state space within the measured budget, so it is not claimed (see
# plans/formal_plan.md). The PSW job does prove by induction.
tasks_for() {
    case "$1" in
        ibm_s360_alu|ibm_s360_addr) echo "bmc cover" ;;
        ibm_s360_psw) echo "bmc prove cover" ;;
        ibm_s360_cpu) echo "bmc cover" ;;
    esac
}

run_job() {
    job=$1
    task=$2
    log="$WORK_DIR/${job}_${task}.log"
    echo "=== formal $job [$task] ==="
    # sby resolves [files] relative to the invocation directory.
    (cd "$FORMAL_DIR" && sby -f -d "$WORK_DIR/${job}_${task}" "$job.sby" "$task" > "$log" 2>&1) || {
        echo "FAILED: $job $task"
        tail -n 40 "$log"
        exit 1
    }
}

JOBS="ibm_s360_alu ibm_s360_addr ibm_s360_psw ibm_s360_cpu"

for job in $JOBS; do
    if [ "$TASK" = "all" ]; then
        for t in $(tasks_for "$job"); do
            run_job "$job" "$t"
        done
    else
        case " $(tasks_for "$job") " in
            *" $TASK "*) run_job "$job" "$TASK" ;;
            *) echo "=== formal $job: task '$TASK' not defined, skipped ===" ;;
        esac
    fi
done

echo "=== formal verification passed (logs in $WORK_DIR) ==="
