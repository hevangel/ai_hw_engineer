#!/bin/sh
set -eu
cd "$(dirname "$0")/../formal"
for task in bmc prove cover;do sby -f -d "../work/formal_$task" address.sby "$task";done
