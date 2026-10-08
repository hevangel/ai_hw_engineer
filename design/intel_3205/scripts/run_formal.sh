#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TASK=${1:-all}
mkdir -p "$HERE/work/formal"
run_task() {
    echo "=== Intel 3205 formal $1 ==="
    (cd "$HERE/formal" && sby -f -d "$HERE/work/formal/$1" intel_3205.sby "$1")
}
case "$TASK" in
    all) run_task bmc; run_task prove; run_task cover ;;
    bmc|prove|cover) run_task "$TASK" ;;
    *) echo "Expected all, bmc, prove or cover" >&2; exit 2 ;;
esac
echo "Intel 3205 FORMAL PASSED"
