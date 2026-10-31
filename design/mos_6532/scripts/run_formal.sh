#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TASK=${1:-all}
case "$TASK" in
    all) TASKS="bmc prove cover" ;;
    bmc|prove|cover) TASKS="$TASK" ;;
    *) echo "Usage: $0 [all|bmc|prove|cover]" >&2; exit 2 ;;
esac
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
for task in $TASKS; do
    sby -f -d "$HERE/work/formal/$task" mos_6532.sby "$task"
done
