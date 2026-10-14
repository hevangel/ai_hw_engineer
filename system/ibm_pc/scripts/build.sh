#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/obj"
as --32 "$SYSTEM/tb/board.S" -o "$SYSTEM/work/board.o"
ld -m elf_i386 -Ttext 0x500 --oformat binary "$SYSTEM/work/board.o" -o "$SYSTEM/work/board.bin"
as --32 "$SYSTEM/tb/disk.S" -o "$SYSTEM/work/disk.o"
ld -m elf_i386 -Ttext 0x500 --oformat binary "$SYSTEM/work/disk.o" -o "$SYSTEM/work/disk.bin"
verilator --cc --exe --build -j 4 -Wall --assert --public-flat-rw \
    --top-module ibm_pc --Mdir "$SYSTEM/work/obj" \
    "$ROOT/design/intel_8086/src/"*.sv \
    "$ROOT/design/intel_8259/src/"*.sv "$ROOT/design/intel_8253_8254/src/"*.sv \
    "$ROOT/design/intel_8255/src/"*.sv "$ROOT/design/intel_8237/src/"*.sv \
    "$ROOT/design/intel_8272/src/intel_8272.sv" "$SYSTEM/src/"*.sv \
    "$SYSTEM/host/simulator.cpp" > "$SYSTEM/work/build.log" 2>&1
