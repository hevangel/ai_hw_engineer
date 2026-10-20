#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
. scripts/sources.sh
verilator --lint-only -Wall --top-module apple_iie $SOURCES
