#!/bin/sh
# Keyboard regression: the AT keyboard model (host/at_keyboard.hpp) on the
# real 8042 running IBM's firmware 1503033, driven by the unchanged BIOS
# on the VGA machine (host/simulator.cpp, batch mode).
#
# Usage: scripts/run_keyboard_test.sh /path/to/atbios.bin
#
# One batch run with the key script
#     when "RESUME" F1        # press F1 when the BIOS asks for it
#     wait 150000000          # then let the BIOS go on
# (at most 1,000,000,000 processor clocks; about 15 minutes). Checks:
#   1. The keyboard received the BIOS's Reset command (FFh) and answered
#      ACK (FAh) and the BAT completion code (AAh).
#   2. The screen when the F1 rule fired, read with the VGA ROM's own font
#      by scripts/check_frame.py, equals scripts/expected_screen_keyboard.txt:
#      the memory count, 601-Diskette Error and the F1 prompt, and no
#      301-Keyboard Error (tb/expected_screen_vga.txt has it, without a
#      keyboard).
#   3. Pressing F1 through the keyboard model: the keyboard sent its set 2
#      make and break (05h, F0h 05h), the processor read the 8042's set 1
#      translation 3Bh and then BBh at port 60h, and the BIOS went on (the
#      prompt is gone and the POST checkpoint is no longer 3Fh).
# The run ends early at the BIOS's 80287 probe (see KNOWN_STOP below).
# Output: $IBM_PC_AT_WORK_DIR (default work)/keyboard_test/
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
if [ "$#" -ne 1 ]; then
    echo "usage: $0 /path/to/atbios.bin" >&2
    exit 2
fi
HOST_LINE=$(sh "$SCRIPT_DIR/build_host.sh" "$1" | tail -n 1)
set -- $HOST_LINE
SIM=$2 ROM=$3 VGA=$4
OUT=$WORK_DIR/keyboard_test
rm -rf "$OUT"
mkdir -p "$OUT"
status=0
json() {   # json EXPR: a Python expression on the final status file as s
    python3 -c "import json,sys; s=json.load(open(sys.argv[1])); print($1)" "$OUT/run/status.json"
}

cat > "$OUT/f1.script" <<'EOF'
when "RESUME" F1
wait 150000000
EOF
echo "== run: press F1 at the BIOS prompt (at most 1,000,000,000 clocks)"
start=$(date +%s)
rc=0
"$SIM" "$ROM" "$VGA" --batch=1000000000 --save-every=50000000 --until-script \
    "--script=$OUT/f1.script" "--out=$OUT/run" "--fst=$OUT/unused.fst" 2> "$OUT/run.log" || rc=$?
echo "wall time $(( $(date +%s) - start )) s; $(tail -n 1 "$OUT/run.log")"
# After F1 the BIOS probes for an 80287 (checkpoint 40h): FNINIT makes the
# 80286 write coprocessor port 0F8h, which no board device decodes (AT17),
# so the machine stops there as the POST runner would. That stop is the
# expected end of this run; any other stop or failure is not.
KNOWN_STOP='io-write port=00F8 at=F000:15EF'
if [ "$rc" -eq 3 ] && [ "$(json "s['state']['stopped']")" = "$KNOWN_STOP" ]; then
    echo "machine stopped as expected after F1: $KNOWN_STOP"
elif [ "$rc" -ne 0 ]; then
    echo "FAIL: the run ended with status $rc: $(json "s['state']['stopped']")" >&2
    status=1
fi
echo "script: $(json "s['scriptLog']")"
echo "keyboard received: $(json "s['state']['keyboard']['receivedLog']")"
echo "keyboard sent:     $(json "s['state']['keyboard']['sentLog']")"
echo "port 60h, last values read: $(json "s['state']['port60Log']")"

echo "== check 1: keyboard reset handshake"
if [ "$(json "s['state']['keyboard']['receivedLog'].split()[:1] == ['FF'] and s['state']['keyboard']['sentLog'].startswith('AA FA AA')")" = True ]; then
    echo "PASS: received FF; sent AA (power-on BAT), FA, AA"
else
    echo "FAIL: the keyboard did not receive Reset (FF) and answer FA, AA" >&2
    status=1
fi

echo "== check 2: screen at the F1 prompt"
if [ -f "$OUT/run/rule1.ppm" ]; then
    python3 "$SCRIPT_DIR/check_frame.py" "$VGA" "$OUT/run/rule1.ppm" \
        "$SCRIPT_DIR/expected_screen_keyboard.txt" "$OUT/run/rule1.png" || status=1
else
    echo "FAIL: the F1 prompt did not appear" >&2
    status=1
fi

echo "== check 3: F1 typed through the keyboard and the 8042"
if [ "$(json "' 05 F0 05' in ' ' + s['state']['keyboard']['sentLog']")" != True ]; then
    echo "FAIL: the keyboard did not send 05, F0 05" >&2
    status=1
fi
if [ "$(json "' '.join(v for v in s['state']['port60Log'].split() if v in ('3B','BB')) == '3B BB'")" != True ]; then
    echo "FAIL: port 60h did not deliver 3Bh then BBh" >&2
    status=1
fi
echo "screen after F1:"
sed 's/^/  | /' "$OUT/run/screen.txt" | grep -v '^  | $' || true
echo "POST checkpoint after F1: $(json "s['state']['post']")"
if grep -q RESUME "$OUT/run/screen.txt" || [ "$(json "s['state']['post']")" = 3F ]; then
    echo "FAIL: the BIOS still waits for F1" >&2
    status=1
fi
[ "$status" -eq 0 ] && echo "PASS: keyboard reset handshake, no 301-Keyboard Error, F1 resumes the BIOS"
exit "$status"
