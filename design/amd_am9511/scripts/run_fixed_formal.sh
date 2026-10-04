#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
mkdir -p "$DESIGN_DIR/work/formal"
cd "$DESIGN_DIR/formal"
sby -f -d "$DESIGN_DIR/work/formal/fixed_bmc" amd_am9511_fixed.sby bmc
sby -f -d "$DESIGN_DIR/work/formal/fixed_prove" amd_am9511_fixed.sby prove
sby -f -d "$DESIGN_DIR/work/formal/fixed_cover" amd_am9511_fixed.sby cover
