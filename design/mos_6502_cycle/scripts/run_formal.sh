#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p work/formal
cd formal
sby -f --prefix ../work/formal/cpu mos_6502_cycle.sby
