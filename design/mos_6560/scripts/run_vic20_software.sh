#!/bin/sh
# Original VIC-20 firmware boot (PAL 901486-07 and NTSC 901486-06 KERNAL)
# on the native 6502, two 6522s and this VIC, compared clock by clock with
# the unchanged MAME VIC functions. Run after run_vic_sim.sh built the oracle.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC="$HERE/src/mos_6560.sv $HERE/src/mos_6560_regs.sv $HERE/src/mos_6560_raster.sv \
$HERE/src/mos_6560_video.sv $HERE/src/mos_6560_lightpen.sv $HERE/src/mos_6560_audio.sv \
$HERE/../mos_6502_family/mos_6502/src/mos_6502_native.sv $HERE/../mos_6522/src/mos_6522.sv"
python3 "$HERE/scripts/fetch_vic20_firmware.py"
test -f "$HERE/work/vic_display_oracle.o"
ROM="$HERE/work/vic20"
for profile in 1 0; do
    # shellcheck disable=SC2086
    verilator --cc --exe --build -Wall -j 4 -GPAL=$profile --top-module vic20_top \
        --Mdir "$HERE/work/vic20-$profile" $SRC "$HERE/tb/vic20_top.sv" \
        "$HERE/tb/vic20_boot_test.cpp" "$HERE/work/vic_display_oracle.o" \
        > "$HERE/work/vic20-build-$profile.log" 2>&1
done
"$HERE/work/vic20-1/Vvic20_top" pal "$ROM/basic.901486-01.bin" "$ROM/kernal.901486-07.bin" \
    "$ROM/characters.901460-03.bin" "$ROM/pal-boot.png" > "$HERE/work/vic20-boot.log" 2>&1
"$HERE/work/vic20-0/Vvic20_top" ntsc "$ROM/basic.901486-01.bin" "$ROM/kernal.901486-06.bin" \
    "$ROM/characters.901460-03.bin" "$ROM/ntsc-boot.png" >> "$HERE/work/vic20-boot.log" 2>&1
grep 'VIC-20 PAL BOOT PASS:' "$HERE/work/vic20-boot.log"
grep 'VIC-20 NTSC BOOT PASS:' "$HERE/work/vic20-boot.log"
