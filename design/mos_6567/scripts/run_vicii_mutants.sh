#!/bin/sh
# Seeded-defect check for the VIC-II oracle comparison: every mutant must
# make tb/vicii_test.cpp fail (PAL 6569 unless the mutant names a variant).
# Run after run_vicii_sim.sh built the oracle object.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$HERE"
test -f work/vicii_oracle.o
survivors=0
killed=0
run() {
    name=$1; variant=$2; from=$3; to=$4
    rm -rf work/mut
    mkdir -p work/mut
    cp src/mos_6567.sv work/mut/mos_6567.sv
    sed -i "s|$from|$to|" work/mut/mos_6567.sv
    if cmp -s src/mos_6567.sv work/mut/mos_6567.sv; then
        echo "MUTANT $name: pattern missing"
        exit 1
    fi
    verilator --cc --exe --build -Wno-fatal -j 4 -O3 -GVARIANT="$variant" --top-module mos_6567 \
        --Mdir work/mut/obj work/mut/mos_6567.sv "$HERE/tb/vicii_test.cpp" \
        "$HERE/work/vicii_oracle.o" > work/mut/build.log 2>&1
    if ./work/mut/obj/Vmos_6567 "$variant" 1 > work/mut/run.log 2>&1; then
        echo "MUTANT $name: SURVIVED"
        survivors=$((survivors + 1))
    else
        echo "MUTANT $name: killed ($(head -c 100 work/mut/run.log))"
        killed=$((killed + 1))
    fi
}
run output_lag 0 "localparam int OUTPUT_LAG = HMOS ? 4 : 3;" "localparam int OUTPUT_LAG = HMOS ? 4 : 2;"
run badline_scroll 0 "rasterline_d\[2:0\] == reg_d\[R_CR1\]\[2:0\]" "rasterline_d[2:0] == 3'd3"
run sprite_xexp 0 "spr_xphase_d\[i\] = !spr_xphase_d\[i\];" "spr_xphase_d[i] = 0;"
run collision_hold 0 "hold_mm_d = 4'd12;" "hold_mm_d = 4'd11;"
run border_left 0 "(cr2\[3\] ? 9'd24 : 9'd31)" "(cr2[3] ? 9'd25 : 9'd31)"
run mcbase_end 0 "if (spr_mcbase_d\[i\] == 6'd63) spr_dma_d\[i\] = 0;" "if (spr_mcbase_d[i] == 6'd62) spr_dma_d[i] = 0;"
run ecm_color 0 "C_B0C + {4'b0000, v\[7:6\]}" "C_B0C + {4'b0000, v[6:5]}"
run color_seen 0 "else if (r >= R_EC \&\& r < 6'h2f) s\[b\] = 0;" "else if (r >= R_EC \&\& r < 6'h2f) s[b] = 1;"
run aec_delay 0 "aec_d = aec_delay_d\[2\];" "aec_d = aec_delay_d[1];"
run refresh 0 "refresh_d = refresh_d - 8'd1;" "refresh_d = refresh_d - 8'd2;"
run lightpen_x 0 "localparam logic \[7:0\] LP_X_OFFSET = HMOS ? 8'd1 : 8'd2;" "localparam logic [7:0] LP_X_OFFSET = HMOS ? 8'd1 : 8'd3;"
run mye_crunch 0 "(6'h2a \& (spr_mcbase_d\[i\] \& spr_mc_d\[i\]))" "(6'h28 \& (spr_mcbase_d[i] \& spr_mc_d[i]))"
run rom_glitch 0 "gaddr = {addr_to\[13:8\], addr_from\[7:0\]};" "gaddr = addr_mode;"
run mcm_flop 0 "mcm_flop_dot = 4'd3 +" "mcm_flop_dot = 4'd2 +"
run priority 0 "if (!(fg \&\& dreg_d\[R_MDP\]\[lowest\]))" "if (!dreg_d[R_MDP][lowest])"
run ntsc_stall 1 "localparam int X_STALL_LENGTH = (NTSC \&\& !NTSC64) ? 2 : 0;" "localparam int X_STALL_LENGTH = 0;"
test "$survivors" -eq 0
echo "MOS 6567 VIC-II MUTATION PASS: $killed of $killed seeded defects detected"
