#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DESIGN_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$DESIGN_DIR/../.." && pwd)
WORK_DIR=${INTEL_80286_WORK_DIR:-$DESIGN_DIR/work}
OUT_DIR="$WORK_DIR/at_bios_native"
if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/pinned-atbios.bin" >&2
    exit 2
fi
ROM=$(CDPATH= cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")
printf '%s  %s\n' 74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f "$ROM" | sha256sum -c -
mkdir -p "$OUT_DIR"
if [ ! -f "$WORK_DIR/oracle/unicorn/__init__.py" ]; then
    python3 -m pip install --target "$WORK_DIR/oracle" unicorn==2.1.4
fi
sha256sum "$DESIGN_DIR"/src/*.sv \
    "$REPO_DIR/design/intel_8253_8254/src/intel_8253_8254.sv" \
    "$REPO_DIR/design/intel_8237/src/intel_8237.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_timer.sv" "$DESIGN_DIR/tb/intel_80286_at_dma.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_page.sv" "$DESIGN_DIR/tb/intel_80286_at_page_map.sv" "$DESIGN_DIR/tb/intel_80286_at_port61.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_request.sv" "$DESIGN_DIR/tb/intel_80286_at_refresh_arbiter.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_detect.sv" "$DESIGN_DIR/tb/intel_80286_at_refresh_row.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_path.sv" "$DESIGN_DIR/tb/intel_80286_at_refresh_native.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_timer_native.sv" "$DESIGN_DIR/tb/intel_80286_at_bios_native.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_memory_ras.sv" "$DESIGN_DIR/tb/at_bios_native.cpp" "$SCRIPT_DIR/run_at_bios_native.sh" \
    "$SCRIPT_DIR/check_at_timer_bios.py" "$SCRIPT_DIR/generate_firmware_trace.py" \
    "$SCRIPT_DIR/generate_vectors.py" "$SCRIPT_DIR/work_paths.py" "$ROM" > "$OUT_DIR/inputs.sha256"
verilator --version > "$OUT_DIR/toolchain.txt"
g++ --version | head -n 1 >> "$OUT_DIR/toolchain.txt"
python3 --version >> "$OUT_DIR/toolchain.txt"
if ! verilator --cc --exe --build -j 2 -Wall -Wno-SYNCASYNCNET --timescale-override 1ns/1ps \
    --top-module intel_80286_at_bios_native --Mdir "$OUT_DIR/obj" \
    "$DESIGN_DIR"/src/*.sv "$REPO_DIR/design/intel_8253_8254/src/intel_8253_8254.sv" \
    "$REPO_DIR/design/intel_8237/src/intel_8237.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_timer.sv" "$DESIGN_DIR/tb/intel_80286_at_dma.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_page.sv" "$DESIGN_DIR/tb/intel_80286_at_page_map.sv" "$DESIGN_DIR/tb/intel_80286_at_port61.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_request.sv" "$DESIGN_DIR/tb/intel_80286_at_refresh_arbiter.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_detect.sv" "$DESIGN_DIR/tb/intel_80286_at_refresh_row.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_path.sv" "$DESIGN_DIR/tb/intel_80286_at_refresh_native.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_refresh_timer_native.sv" "$DESIGN_DIR/tb/intel_80286_at_bios_native.sv" \
    "$DESIGN_DIR/tb/intel_80286_at_memory_ras.sv" "$DESIGN_DIR/tb/at_bios_native.cpp" > "$OUT_DIR/build.log" 2>&1; then
    cat "$OUT_DIR/build.log" >&2
    exit 1
fi
for scenario in '0 8' '1 11'; do
    set -- $scenario
    if ! "$OUT_DIR/obj/Vintel_80286_at_bios_native" "$ROM" "$OUT_DIR/trace_wait${1}_half${2}.txt" "$1" "$2" \
        > "$OUT_DIR/run_wait${1}_half${2}.log" 2>&1; then
        cat "$OUT_DIR/run_wait${1}_half${2}.log" >&2
        exit 1
    fi
    cat "$OUT_DIR/run_wait${1}_half${2}.log"
    if ! PYTHONPATH="$WORK_DIR/oracle${PYTHONPATH:+:$PYTHONPATH}" python3 "$SCRIPT_DIR/check_at_timer_bios.py" \
        "$ROM" "$OUT_DIR/trace_wait${1}_half${2}.txt" refresh > "$OUT_DIR/oracle_wait${1}_half${2}.log" 2>&1; then
        cat "$OUT_DIR/oracle_wait${1}_half${2}.log" >&2
        exit 1
    fi
    cat "$OUT_DIR/oracle_wait${1}_half${2}.log"
done
sha256sum -c "$OUT_DIR/inputs.sha256" > "$OUT_DIR/source_verification.log"
