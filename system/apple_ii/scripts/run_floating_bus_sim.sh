#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work
python3 scripts/generate_rev0.py --check
iverilog -g2012 -s tb_rev0_floating_bus -o work/floating_bus.vvp \
    ../../design/apple_ii_chips/src/*.sv src/apple_ii_rev0_digital.sv tb/tb_rev0_floating_bus.sv \
    >work/floating_bus_compile.log 2>&1 || { cat work/floating_bus_compile.log; exit 1; }
vvp work/floating_bus.vvp >work/floating_bus.log 2>&1 || { cat work/floating_bus.log; exit 1; }
cat work/floating_bus.log
grep -q 'PASS physical floating data bus' work/floating_bus.log
# A negative control must fail the same phase-boundary assertion without charge.
iverilog -g2012 -Ptb_rev0_floating_bus.RETENTION=0 -s tb_rev0_floating_bus \
    -o work/floating_bus_no_charge.vvp ../../design/apple_ii_chips/src/*.sv \
    src/apple_ii_rev0_digital.sv tb/tb_rev0_floating_bus.sv \
    >work/floating_bus_no_charge_compile.log 2>&1 || { cat work/floating_bus_no_charge_compile.log; exit 1; }
if vvp work/floating_bus_no_charge.vvp >work/floating_bus_no_charge.log 2>&1; then
    echo 'ERROR: negative control unexpectedly passed without retained charge' >&2
    exit 1
fi
grep -q 'Floating read c020' work/floating_bus_no_charge.log
echo 'PASS negative control: original ideal-Z board fails the C020 floating-read assertion'
