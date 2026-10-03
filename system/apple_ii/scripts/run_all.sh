#!/bin/sh
set -e
cd "$(dirname "$0")/.."
./scripts/run_sim.sh
echo "Apple II firmware boot regression is pending; system sign-off is incomplete."
exit 1
