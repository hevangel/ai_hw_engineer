#!/bin/sh
# Seeded-defect check for the complete-VIC oracle comparison: every mutant
# must make tb/vic_test.cpp fail. Run after run_vic_sim.sh built the oracle.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$HERE"
test -f work/vic_display_oracle.o
survivors=0
killed=0
run() {
    name=$1; file=$2; from=$3; to=$4
    rm -rf work/mut
    mkdir -p work/mut/src
    cp src/*.sv work/mut/src/
    sed -i "s|$from|$to|" "work/mut/src/$file"
    if cmp -s "src/$file" "work/mut/src/$file"; then
        echo "MUTANT $name: pattern missing"
        exit 1
    fi
    verilator --cc --exe --build -Wno-fatal -j 4 --top-module vic_pair --Mdir work/mut/obj \
        work/mut/src/mos_6560.sv work/mut/src/mos_6560_regs.sv work/mut/src/mos_6560_raster.sv \
        work/mut/src/mos_6560_video.sv work/mut/src/mos_6560_lightpen.sv \
        work/mut/src/mos_6560_audio.sv tb/vic_pair.sv "$HERE/tb/vic_test.cpp" \
        "$HERE/work/vic_display_oracle.o" > work/mut/build.log 2>&1
    if ./work/mut/obj/Vvic_pair /dev/null 0 > work/mut/run.log 2>&1; then
        echo "MUTANT $name: SURVIVED"
        survivors=$((survivors + 1))
    else
        echo "MUTANT $name: killed"
        killed=$((killed + 1))
    fi
}
run load_delay mos_6560_video.sv "if (load_d\[0\]) begin" "if (load_d[1]) begin"
run reverse_phase mos_6560_video.sv "if (i == 3 \&\& pend_q == PEND_COLOR)" "if (i == 2 \&\& pend_q == PEND_COLOR)"
run tall_mask mos_6560_video.sv "ycounter_d\[3\] \& tall" "1'b0"
run start_delay mos_6560_video.sv "start_delay_d = 3'd4;" "start_delay_d = 3'd3;"
run wrap_inc mos_6560_video.sv "vmc_d = vmc_d + 12'h100;" "vmc_d = vmc_d;"
run columns mos_6560_video.sv "6'd32 : 6'd31" "6'd31 : 6'd31"
run pen_extra mos_6560_lightpen.sv "extra_d = 0;" "extra_d = 1;"
run pen_relock mos_6560_lightpen.sv "triggered_d = 0;" "triggered_d = triggered_d;"
run noise_tap mos_6560_audio.sv "lfsr_q\[12\]" "lfsr_q[13]"
run noise_edge mos_6560_audio.sv "lfsr_q\[0\] \&\& !lfsr0_q" "lfsr_q[0]"
run prescale mos_6560_audio.sv "1: prescale = 8'h07;" "1: prescale = 8'h0f;"
run raster_next mos_6560_raster.sv "readback(h_d, line_d, field_d, interlace_d, frame_lines_d)" "readback(h_q, line_q, field_q, interlace_q, frame_lines_q)"
test "$survivors" -eq 0
echo "MOS 6560 VIC MUTATION PASS: $killed of $killed seeded defects detected"
