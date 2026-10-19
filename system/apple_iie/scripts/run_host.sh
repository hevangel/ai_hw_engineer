#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 scripts/fetch_firmware.py
. scripts/sources.sh
if test "${SIMULATOR:-verilator}" = xezim;then
    cc -std=c11 -Wall -Wextra -Werror -fPIC -shared host/panel.c -o work/panel.so
    printf '%s\n' "$SOURCES" >work/panel_sources.txt
else
    mkdir -p work/firmware
    verilator --cc --exe --build -j 4 -Wall --top-module apple_iie --Mdir work/firmware $SOURCES "$(pwd)/tb/firmware.cpp" "$(pwd)/host/panel.c" >work/host_build.log 2>&1
fi
exec python3 host/server.py "$@"
