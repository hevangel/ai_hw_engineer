#!/bin/sh
set -eu
SYSTEM=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ROOT=$(dirname "$(dirname "$SYSTEM")")
mkdir -p "$SYSTEM/work/obj"
as --32 "$SYSTEM/tb/fpu.S" -o "$SYSTEM/work/fpu.o"
ld -m elf_i386 -Ttext 0x500 --oformat binary "$SYSTEM/work/fpu.o" -o "$SYSTEM/work/fpu.bin"
as --32 "$SYSTEM/tb/dos_fpu.S" -o "$SYSTEM/work/dos_fpu.o"
ld -m elf_i386 -Ttext 0x100 --oformat binary "$SYSTEM/work/dos_fpu.o" -o "$SYSTEM/work/FPU8087.COM"
verilator --cc --exe --build -j 4 -Wall --assert --savable -MAKEFLAGS OPT_FAST=-O3 --public-flat-rw --trace-fst --trace-depth 2 \
    -I"$ROOT/design/intel_8087/src" --top-module ibm_pc_xt_5160 --Mdir "$SYSTEM/work/obj" \
    "$ROOT/design/intel_8086/src/"*.sv "$ROOT/design/intel_8087/src/"*.sv \
    "$ROOT/design/intel_8259/src/"*.sv "$ROOT/design/intel_8253_8254/src/"*.sv \
    "$ROOT/design/intel_8255/src/"*.sv "$ROOT/design/intel_8237/src/"*.sv \
    "$ROOT/design/intel_8272/src/intel_8272.sv" "$ROOT/system/ibm_pc/src/ibm_pc_bus.sv" \
    "$SYSTEM/src/"*.sv "$SYSTEM/host/simulator.cpp" > "$SYSTEM/work/build.log" 2>&1
