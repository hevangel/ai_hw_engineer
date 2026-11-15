#!/bin/sh
set -eu
# Am29C323 qualification: runs the shared Am29323 verification suite
# against the shared RTL module (see ../am29323/). The CMOS member's
# function is documented identical; no RTL is duplicated here.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$SCRIPT_DIR/../../am29323/scripts/run_all.sh"
echo '=== Am29C323 qualification (shared Am29323 suite) PASSED ==='
