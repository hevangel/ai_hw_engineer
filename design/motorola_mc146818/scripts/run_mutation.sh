#!/bin/sh
# Mutation check: plant faults in copies of the RTL and require the
# simulation flow (directed tests, 4 random seeds, BIOS replay) to show a
# behavioral difference for each. The original RTL is not modified.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${MC146818_WORK_DIR:-$ROOT/work}/mutation
PY=${PYTHON:-python3}
mkdir -p "$WORK"
echo "== mutation check"

mutate() {   # NAME DESCRIPTION FROM TO
    f="$WORK/$1.sv"
    "$PY" - "$ROOT/src/motorola_mc146818.sv" "$f" "$3" "$4" <<'PYEOF'
import sys
src, dst, a, b = sys.argv[1:5]
s = open(src).read()
if s.count(a) != 1:
    sys.exit('mutation anchor not found exactly once: %r' % a)
open(dst, 'w').write(s.replace(a, b))
PYEOF
    if MC146818_RTL="$f" MC146818_WORK_DIR="$WORK/$1" MC146818_NO_COVERAGE_GATE=1 \
        sh "$ROOT/scripts/run_sim.sh" 4 600 >"$WORK/$1.log" 2>&1; then
        echo "FAIL: mutant $1 ($2) survived"
        exit 1
    fi
    # A kill must be a behavioral difference, not a build or tool error.
    why=$(grep -m1 -E '^FAIL: (RTL differs|checkpoint|dead-battery|battery-good|CMOS|SET_TOD|UIP)' \
          "$WORK/$1.log" || true)
    if [ -z "$why" ]; then
        echo "FAIL: mutant $1 stopped the flow without a behavioral difference:"
        tail -5 "$WORK/$1.log"
        exit 1
    fi
    echo "killed $1: $2 -- $(echo "$why" | sed "s#$WORK/##" | cut -c1-100)"
}

mutate m1_regc_not_cleared "register C read does not clear PF" \
    "(pf & ~(rd_c & c_hold[6])) | pf_edge" "pf | pf_edge"
mutate m2_bcd_leap_units_only "BCD leap year ignores the tens digit" \
    "else     leap = (({t_yr[4], 1'b0} + t_yr[1:0]) == 2'd0);" "else     leap = (t_yr[1:0] == 2'd0);"
mutate m3_set_keeps_uie "SET going high does not clear UIE" \
    "if (set_rise) b_wr[4] = 1'b0;" "if (set_rise) b_wr[4] = b_wr[4];"
mutate m4_tbuc_short "tBUC of 7 instead of 8 periods at 32.768 kHz" \
    "default: begin t_buc = 11'd8;" "default: begin t_buc = 11'd7;"
mutate m5_alarm_dontcare_bit7 "minutes alarm don't-care decoded from bit 7 only" \
    "(mem[3] == n_min || mem[3][7:6] == 2'b11)" "(mem[3] == n_min || mem[3][7])"
mutate m6_reset_keeps_sqwe "RESET pin does not clear SQWE" \
    "mem_n[A_REGB][6:3] = 4'b0;" "mem_n[A_REGB][6:4] = 3'b0;"
echo "PASS: 6 of 6 mutants killed"
