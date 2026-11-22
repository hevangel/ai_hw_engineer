#!/bin/sh
# 8086/8088 PC compatibility regression of the IBM PC AT 5170 (VGA machine,
# unchanged AT REV1 BIOS): the IBM PC's diskette DOS workloads, run on the AT
# and, with the same keystrokes, on the repository's 8088 machines, then
# compared.
#
#   dos100  PC DOS 1.00 (160 KB, system/ibm_pc/scripts/prepare_images.py) in
#           the 1.2 MB drive A, the PC system's blank 160 KB data diskette in
#           the 360 KB drive B: the steps of system/ibm_pc/scripts/
#           test_software.py (date, DIR, CHKDSK, FORMAT B:, COPY to B:,
#           DIR B:, BASIC PRINT 6*7, BASICA DONKEY); reference: system/ibm_pc
#   dos200  PC DOS 2.00 Disk 1 (180 KB) in drive A, Disk 2 in drive B
#           (system/ibm_pc_xt_5160/scripts/prepare_images.py): date and
#           time, DIR, ECHO and COPY CON into files on B:, TYPE them back,
#           BASIC PRINT 6*7; reference: system/ibm_pc_xt_5160 booted from A
#
# The AT's MC146818 starts from tb/cmos_vga_2fd.hex (drive B a 360 KB drive).
# Every 80286 instruction of both AT runs, from power-on to the end of the
# workload, is replayed against Unicorn (scripts/check_post_trace.py).
#
# Usage: scripts/run_dos_8086.sh /path/to/atbios.bin [--no-reference] [--no-oracle]
#   --no-reference  run only the AT (no 8088 runs, no comparison)
#   --no-oracle     no processor trace and no Unicorn replay
# Output: $IBM_PC_AT_WORK_DIR (default work)/dos_8086/
# Takes about 1.5 hours of simulation (the four runs in parallel) and about
# 2 hours more for the Unicorn replays (also in parallel); traces need about
# 10 GB.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SYS_DIR=$(dirname "$SCRIPT_DIR")
REPO_DIR=$(CDPATH= cd -- "$SYS_DIR/../.." && pwd)
WORK_DIR=${IBM_PC_AT_WORK_DIR:-$SYS_DIR/work}
CPU_DIR=$REPO_DIR/design/intel_80286
PC_DIR=$REPO_DIR/system/ibm_pc
XT_DIR=$REPO_DIR/system/ibm_pc_xt_5160
[ "$#" -ge 1 ] || { echo "usage: $0 /path/to/atbios.bin [--no-reference] [--no-oracle]" >&2; exit 2; }
BIOS_ARG=$1
shift
REFERENCE=1 ORACLE=1
for o in "$@"; do
    case $o in
        --no-reference) REFERENCE=0 ;;
        --no-oracle) ORACLE=0 ;;
        *) echo "unknown option $o" >&2; exit 2 ;;
    esac
done
OUT=$WORK_DIR/dos_8086
rm -rf "$OUT"
mkdir -p "$OUT"
status=0

echo "== media: pinned, hash-checked PC DOS 1.00 and 2.00 images"
python3 "$PC_DIR/scripts/prepare_images.py"
python3 "$XT_DIR/scripts/prepare_images.py"
PC_REF=$PC_DIR/work/reference
XT_REF=$XT_DIR/work/reference

echo "== build the AT host simulator with two diskette drives (tb/cmos_vga_2fd.hex)"
HOST_LINE=$(AT_HOST_CMOS="$SYS_DIR/tb/cmos_vga_2fd.hex" AT_HOST_OBJ="$WORK_DIR/host/obj_2fd" \
    sh "$SCRIPT_DIR/build_host.sh" "$BIOS_ARG" | tail -n 1)
set -- $HOST_LINE
SIM=$2 ROM=$3 VGA=$4
if [ "$REFERENCE" -eq 1 ]; then
    echo "== build the 8088 reference machines (system/ibm_pc, system/ibm_pc_xt_5160)"
    sh "$PC_DIR/scripts/build.sh"
    sh "$XT_DIR/scripts/build.sh"
fi

WL=$SCRIPT_DIR/dos_8086_workload.py
trace() { [ "$ORACLE" -eq 1 ] && echo "--trace=$OUT/$1.trace" || true; }
echo "== run the workloads (in parallel; logs in $OUT/*.out)"
pids=
python3 "$WL" at dos100 "$OUT/at_dos100" "$SIM" "$ROM" "$VGA" "$PC_REF/pcdos100.img" \
    "$PC_REF/workdisk.img" $(trace at_dos100) > "$OUT/at_dos100.out" 2>&1 & pids="$pids $!"
python3 "$WL" at dos200 "$OUT/at_dos200" "$SIM" "$ROM" "$VGA" "$XT_REF/pcdos200.img" \
    "$XT_REF/tools200.img" $(trace at_dos200) > "$OUT/at_dos200.out" 2>&1 & pids="$pids $!"
if [ "$REFERENCE" -eq 1 ]; then
    python3 "$WL" pc dos100 "$OUT/pc_dos100" "$PC_DIR/work/obj/Vibm_pc" "$PC_REF" \
        > "$OUT/pc_dos100.out" 2>&1 & pids="$pids $!"
    python3 "$WL" xt dos200 "$OUT/xt_dos200" "$XT_DIR/work/obj/Vibm_pc_xt_5160" "$XT_REF" \
        "$XT_DIR/work/harddisk.img" > "$OUT/xt_dos200.out" 2>&1 & pids="$pids $!"
fi
for p in $pids; do wait "$p" || status=1; done
for f in "$OUT"/*.out; do
    echo "-- $(basename "$f")"
    sed 's/^/  /' "$f"
done
[ "$status" -eq 0 ] || { echo "FAIL: a workload run failed" >&2; exit 1; }

if [ "$REFERENCE" -eq 1 ]; then
    echo "== compare: PC 5150 (8088) and AT, PC DOS 1.00"
    python3 "$SCRIPT_DIR/compare_8086.py" "$OUT/pc_dos100" "$OUT/at_dos100" "$PC_REF/pcdos100.img" || status=1
    echo "== compare: PC XT 5160 (8088) and AT, PC DOS 2.00"
    python3 "$SCRIPT_DIR/compare_8086.py" "$OUT/xt_dos200" "$OUT/at_dos200" "$XT_REF/pcdos200.img" || status=1
fi

if [ "$ORACLE" -eq 1 ]; then
    echo "== 80286 against Unicorn, every instruction of both AT runs"
    if [ ! -f "$WORK_DIR/oracle/unicorn/__init__.py" ]; then
        python3 -m pip install --quiet --target "$WORK_DIR/oracle" unicorn==2.1.4
    fi
    opids=
    for run in at_dos100 at_dos200; do
        # The simulator ends the trace when it quits and logs where.
        end=$(sed -n 's/^TRACE end=\([0-9A-F]*:[0-9A-F]*\) .*/\1/p' "$OUT/$run/simulator.log")
        if [ -z "$end" ]; then
            echo "FAIL: no trace end in $OUT/$run/simulator.log" >&2
            status=1
            continue
        fi
        PYTHONPATH="$WORK_DIR/oracle:$CPU_DIR/scripts${PYTHONPATH:+:$PYTHONPATH}" \
            python3 "$SCRIPT_DIR/check_post_trace.py" "$ROM" "$OUT/$run.trace" "$end" "C0000:$VGA" --boot \
            > "$OUT/$run.oracle.log" 2>&1 & opids="$opids $!"
    done
    for p in $opids; do wait "$p" || status=1; done
    for run in at_dos100 at_dos200; do
        echo "-- $run"
        sed 's/^/  /' "$OUT/$run.oracle.log"
    done
fi
[ "$status" -eq 0 ] && echo "PASS: the AT runs the 8088 PC's DOS 1.00 and 2.00 diskette workloads with the same results"
exit "$status"
