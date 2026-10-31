#!/bin/sh
# Seeded-defect check for the SID oracle comparison: every mutant must make
# tb/sid_test.cpp fail. Run after run_sid_sim.sh built the oracle library.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$HERE"
test -f work/sid_oracle.o
test -f work/libresidfp.a
survivors=0
killed=0
run() {
    name=$1; model=$2; from=$3; to=$4
    rm -rf work/mut
    mkdir -p work/mut
    cp src/mos_6581.sv work/mut/mos_6581.sv
    sed -i "s#$from#$to#" work/mut/mos_6581.sv
    if cmp -s src/mos_6581.sv work/mut/mos_6581.sv; then
        echo "MUTANT $name: pattern missing"
        exit 1
    fi
    verilator --cc --exe --build -Wno-fatal -j 4 -O3 --public-flat-rw -GMOS8580="$model" \
        --top-module mos_6581 --Mdir work/mut/obj work/mut/mos_6581.sv "$HERE/tb/sid_test.cpp" \
        "$HERE/work/sid_oracle.o" "$HERE/work/libresidfp.a" > work/mut/build.log 2>&1
    if SID_SR_CHECK=1 ./work/mut/obj/Vmos_6581 "$model" 1 > work/mut/run.log 2>&1; then
        echo "MUTANT $name: SURVIVED"
        survivors=$((survivors + 1))
    else
        echo "MUTANT $name: killed ($(head -c 100 work/mut/run.log))"
        killed=$((killed + 1))
    fi
}
run adsr_table 0 "4'h3: adsr_rate = 15'h0660;" "4'h3: adsr_rate = 15'h0661;"
run exp_threshold 0 "8'h5d: exponential_period = 5'd2;" "8'h5e: exponential_period = 5'd2;"
run sustain_compare 0 "env_d\[i\] != sustain_d\[i\]" "env_d[i][7:4] != sustain_d[i][7:4]"
run attack_pipeline 0 "state_pipe_d\[v\] = 2'd2;" "state_pipe_d[v] = 2'd3;"
run gate_delay 0 "3'd2 : 3'd4;" "3'd2 : 3'd3;"
run noise_writeback 0 "noise_writeback\[13\] = w\[3\];" "noise_writeback[13] = w[2];"
run shift_feedback 0 "(tor | l\[0\]) ^ l\[5\]" "(tor | l[0]) ^ l[6]"
run sync_rule 0 "!(sync_d\[i\] \&\& msb_d\[prev_v\])" "1'b1"
run ring_mod 0 "\& ~acc_d\[prev_v\]" "\& acc_d[prev_v]"
run msb_clear 0 "acc_d\[i\]\[23\] = 0;" "acc_d[i][23] = acc_d[i][23];"
run pulse_compare 1 "(acc_d\[i\]\[23:12\] >= pw_d\[i\])" "(acc_d[i][23:12] > pw_d[i])"
run bus_discharge 0 "ttl_d = {1'b0, ttl_d\[19:1\]};" "ttl_d = ttl_d;"
run triangle 0 "{ix\[10:0\] ^ 11'h7ff, 1'b0}" "{ix[10:0], 1'b0}"
run floating_fade 0 "localparam int FLOATING_FADE = MOS8580 ? 50000 : 1400;" "localparam int FLOATING_FADE = MOS8580 ? 50000 : 1300;"
run sr_fade 1 "sr_d\[i\] = sr_d\[i\] | {1'b0, sr_d\[i\]\[22:1\]};" "sr_d[i] = sr_d[i] | {sr_d[i][21:0], 1'b0};"
test "$survivors" -eq 0
echo "MOS 6581 SID MUTATION PASS: $killed of $killed seeded defects detected"
