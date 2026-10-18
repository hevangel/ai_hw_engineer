#!/bin/sh
set -eu
D=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$D/work"
echo 'Intel 8087: strict RTL lint'
verilator --lint-only -Wall -I"$D/src" --top-module intel_8087 "$D/src/"*.sv
