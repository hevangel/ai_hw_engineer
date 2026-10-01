#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Physical open pins and pullup primitives produce UNDRIVEN diagnostics in
# Verilator; direction-enabled 8T28 feedback produces UNOPTFLAT. Both are
# retained in the simulation model and audited in the connectivity manifest.
verilator --lint-only --timing -Wall -Wno-UNUSEDSIGNAL -Wno-PINCONNECTEMPTY \
    -Wno-UNDRIVEN -Wno-UNOPTFLAT \
    --top-module apple_ii_rev0_digital ../../design/apple_ii_chips/src/*.sv src/apple_ii_rev0_digital.sv
