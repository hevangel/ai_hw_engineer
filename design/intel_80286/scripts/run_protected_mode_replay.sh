#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
design_dir="$(cd -- "$script_dir/.." && pwd -P)"
work_root="$design_dir/work"
run_name="${1:-protected_mode_replay_$(date -u +%Y%m%dT%H%M%SZ)}"
if [[ $# -gt 1 || ! "$run_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Usage: $0 [new-run-name: letters, digits, underscores, hyphens]" >&2
  exit 1
fi
mkdir -p "$work_root"

resolved_work_root="$(cd -- "$work_root" && pwd -P)"
if [[ "$resolved_work_root" != "$design_dir/work" ]]; then
  echo "Refusing to use unexpected work directory: $resolved_work_root" >&2
  exit 1
fi
result_dir="$resolved_work_root/$run_name"
if [[ -e "$result_dir" || -L "$result_dir" ]]; then
  echo "Refusing to overwrite existing evidence directory: $result_dir" >&2
  exit 1
fi
build_dir="$result_dir/build"
mkdir -p "$build_dir"

rtl_files=(
  "$design_dir/src/intel_80286.sv"
  "$design_dir/src/intel_80286_access_check.sv"
  "$design_dir/src/intel_80286_alu.sv"
  "$design_dir/src/intel_80286_bus_owner.sv"
  "$design_dir/src/intel_80286_cached_reference.sv"
  "$design_dir/src/intel_80286_code_check.sv"
  "$design_dir/src/intel_80286_code_load.sv"
  "$design_dir/src/intel_80286_decimal.sv"
  "$design_dir/src/intel_80286_ea.sv"
  "$design_dir/src/intel_80286_event_control.sv"
  "$design_dir/src/intel_80286_muldiv.sv"
  "$design_dir/src/intel_80286_segment_check.sv"
  "$design_dir/src/intel_80286_segment_load.sv"
  "$design_dir/src/intel_80286_shift.sv"
)

echo "Building protected-mode replay in $build_dir"
MAKEFLAGS=-B verilator --cc --exe --build -j 2 -Wall --top-module intel_80286 \
  --Mdir "$build_dir" -CFLAGS "-std=c++17" \
  "${rtl_files[@]}" "$design_dir/tb/protected_mode_replay.cpp"

echo "Running protected-mode replay"
"$build_dir/Vintel_80286" 2>&1 | tee "$result_dir/replay.log"
python3 "$design_dir/scripts/record_protected_mode_manifest.py" \
  "$design_dir" "$build_dir" "$result_dir"
