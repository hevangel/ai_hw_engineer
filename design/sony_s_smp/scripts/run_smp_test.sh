#!/bin/sh
# S-SMP real-software gate. Runs the Peter Lemon test ROMs that
# exercise this chip on the SNES board and compares each frame with the
# author's reference screen (or checks for non-silent sound). Expected
# results come only from those external files (see
# system/snes/scripts/test_software.py).
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SYSTEM=$(dirname "$(dirname "$HERE")")/system/snes
python3 "$SYSTEM/scripts/fetch_roms.py"
python3 "$(dirname "$HERE")/sony_s_smp/scripts/fetch_ipl.py"
[ -x "$SYSTEM/work/obj/Vsnes" ] || SNES_REGIONS=0 sh "$SYSTEM/scripts/build.sh"
python3 "$SYSTEM/scripts/test_software.py" CPUTest/SPC700/ SPC700/
