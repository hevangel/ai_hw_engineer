#!/bin/sh
# Run every Apple II system gate except the two long cassette gates (S5 runs
# those separately), recording exit status and wall time for the status table.
set -u
cd /work/system/apple_ii
mkdir -p work/sweep
: > work/sweep/results.tsv
run() {
    name=$1
    shift
    start=$(date +%s)
    if "$@" > "work/sweep/$name.log" 2>&1; then rc=0; else rc=$?; fi
    end=$(date +%s)
    printf '%s\t%s\t%s\n' "$name" "$rc" "$((end - start))" >> work/sweep/results.tsv
    echo "$name rc=$rc $((end - start))s"
}
run copper python3 scripts/check_copper_ic_wiring.py
run packages sh ../../design/apple_ii_chips/scripts/run_all.sh
run package_synth sh ../../design/apple_ii_chips/scripts/run_synth.sh
run lint sh scripts/run_lint.sh
run board sh scripts/run_board_sim.sh
run floating_bus sh scripts/run_floating_bus_sim.sh
run peripheral sh scripts/run_peripheral_sim.sh
run output sh scripts/run_output_sim.sh
run video sh scripts/run_video_sim.sh
run reference_smoke sh scripts/run_reference_smoke.sh
run reference_boot sh scripts/run_reference_boot.sh
run cassette sh scripts/run_cassette_sim.sh
run host_test sh scripts/run_host_test.sh
run basic sh scripts/run_basic_sim.sh
run authored_boot sh scripts/run_authored_boot.sh
run authored_cassette sh scripts/run_authored_cassette.sh
run cassette_firmware sh scripts/run_cassette_command_firmware.sh
run timing sh scripts/run_timing_sim.sh
echo SWEEP-DONE
