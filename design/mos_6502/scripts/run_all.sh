#!/bin/sh
set -e
cd "$(dirname "$0")/.."
./scripts/run_sim.sh
echo "Full 6502 sign-off is pending: authentic Apple II ROM regression is not yet available."
exit 1
