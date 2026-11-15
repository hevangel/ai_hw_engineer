#!/bin/sh
# SymbiYosys: unbounded proof (abc pdr) and cover of the core properties.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT/formal"
echo "== formal"
sby -f upi42_core.sby
echo "PASS: formal prove and cover"
