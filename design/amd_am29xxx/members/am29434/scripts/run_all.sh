#!/bin/sh
set -eu
# Am29434 qualification: runs the shared Am29334 verification suite
# against the shared RTL module (see ../am29334/). The ECL member's
# function is documented identical; no RTL is duplicated here.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
sh "$SCRIPT_DIR/../../am29334/scripts/run_all.sh"
echo '=== Am29434 qualification (shared Am29334 suite) PASSED ==='
