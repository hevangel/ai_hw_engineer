#!/bin/sh
# Fetch the pinned IBM AT REV1 BIOS into this system's ignored work folder,
# using the 286 design's hash-checked download (PCjs archive, see
# design/intel_80286/scripts/prepare_software.py). Prints the ROM path.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
INTEL_80286_WORK_DIR=$WORK_DIR/cpu python3 "$REPO_DIR/design/intel_80286/scripts/prepare_software.py" >&2
mkdir -p "$WORK_DIR/software"
cp "$WORK_DIR/cpu/software/atbios.bin" "$WORK_DIR/software/atbios.bin"
printf '%s  %s\n' 74e7b36b4ec0adc5ac3277a887579996c1d2aa755b9892ef3afe7485c10ce04f \
    "$WORK_DIR/software/atbios.bin" | sha256sum -c - >&2
echo "$WORK_DIR/software/atbios.bin"
