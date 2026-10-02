#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
verilator --lint-only -Wall --top-module mos_6502 src/mos_6502.sv
# Package NC pins and intentionally unconnected architectural observers.
# Core lint above has no warning exclusions; socket clocks use explicit timescale.
verilator --lint-only -Wall -Wno-PINCONNECTEMPTY -Wno-UNUSEDSIGNAL -Wno-TIMESCALEMOD \
    --top-module a2_mos6502 src/mos_6502.sv src/a2_mos6502.sv
