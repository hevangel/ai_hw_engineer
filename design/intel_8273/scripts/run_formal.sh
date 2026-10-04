#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$HERE/work/formal"
cd "$HERE/formal"
case "${1:-all}" in
  all) tasks='bmc prove cover_tx cover_rx cover_error' ;;
  cover) tasks='cover_tx cover_rx cover_error' ;;
  *) tasks=$1 ;;
esac
for task in $tasks; do
  sby -f -d "$HERE/work/formal/$task" intel_8273.sby "$task"
done
echo '8273 FORMAL PASSED'
