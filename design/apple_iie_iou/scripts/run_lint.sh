#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
echo "=== Apple IIe IOU verilator lint (RTL, no waivers) ==="
verilator --lint-only -Wall --top-module apple_iie_iou "$HERE/src/apple_iie_iou.sv"
echo "=== Apple IIe IOU verilator lint (TB waivers) ==="
verilator --lint-only -Wall -Wno-BLKSEQ -Wno-PROCASSINIT -Wno-UNUSEDSIGNAL \
    --top-module tb_top "$HERE/src/apple_iie_iou.sv" "$HERE/tb/tb_top.sv"
