#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
for suite in fixed float derived math host firmware; do
 echo "Simulation $suite"
 sh "$SCRIPT_DIR/run_${suite}.sh"
done
