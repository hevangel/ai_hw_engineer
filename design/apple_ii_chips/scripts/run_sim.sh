#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
for test in tb/tb_*.sv; do
    top=$(basename "$test" .sv)
    [ "$top" != tb_analog ] || continue
    echo "Simulating $top"
    XEZIM_TWO_STATE=0 xezim --simulate --error-exit -s "$top" src/*.sv "$test" --max-time 1ms >"work/$top.log" 2>&1 || { cat "work/$top.log"; exit 1; }
    cat "work/$top.log"
    grep -q 'PASS ' "work/$top.log" || { echo "Missing success marker: $top" >&2; exit 1; }
done
