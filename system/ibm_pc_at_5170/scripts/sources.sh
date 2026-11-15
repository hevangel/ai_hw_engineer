# RTL source list of the IBM PC AT 5170 board, shared by run_post.sh and
# run_synth.sh. Sourced with REPO_DIR and SYS_DIR set; defines BOARD_RTL.
CPU_DIR=$REPO_DIR/design/intel_80286
KBC_DIR=$REPO_DIR/design/intel_mcs48/intel_8042
RTC_DIR=$REPO_DIR/design/motorola_mc146818
BOARD_RTL="$CPU_DIR/src/*.sv
 $REPO_DIR/design/intel_8253_8254/src/intel_8253_8254.sv
 $REPO_DIR/design/intel_8237/src/intel_8237.sv
 $CPU_DIR/tb/intel_80286_at_timer.sv $CPU_DIR/tb/intel_80286_at_dma.sv
 $CPU_DIR/tb/intel_80286_at_page.sv $CPU_DIR/tb/intel_80286_at_page_map.sv
 $CPU_DIR/tb/intel_80286_at_port61.sv $CPU_DIR/tb/intel_80286_at_refresh_request.sv
 $CPU_DIR/tb/intel_80286_at_refresh_arbiter.sv $CPU_DIR/tb/intel_80286_at_refresh_detect.sv
 $CPU_DIR/tb/intel_80286_at_refresh_row.sv $CPU_DIR/tb/intel_80286_at_refresh_path.sv
 $CPU_DIR/tb/intel_80286_at_memory_ras.sv
 $KBC_DIR/src/upi42_core.sv $KBC_DIR/src/intel_8042.sv
 $RTC_DIR/src/motorola_mc146818.sv
 $SYS_DIR/src/ibm_pc_at_5170.sv"
