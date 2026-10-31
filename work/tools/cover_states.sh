#!/bin/sh
set -eu
cd /work/design/mos_6502_family/mos_6502/cycle/formal
for s in 32 9 13; do
    sed "s/COVER_STATE/6'd$s/" cover_one.tpl.sv > cover_one.sv
    echo "--- state $s ---"
    sby -f --prefix "../work/formal/one_s$s" cover_one.sby 2>&1 | grep -E 'DONE|unreached' || true
done
