#!/bin/sh
# usage: run.sh <top> <file...>
set -e
top="$1"; shift
xezim --simulate -s "$top" --error-exit "$@" 2>&1
