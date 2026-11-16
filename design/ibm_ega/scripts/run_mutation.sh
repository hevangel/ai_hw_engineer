#!/bin/sh
# Mutation check: plant faults in copies of the RTL and require the
# simulation flow (39 directed tests and 4 random seeds, lockstep against
# the model) to show a behavioral difference for each. The original RTL is
# not modified.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${EGA_WORK_DIR:-$ROOT/work}/mutation
PY=${PYTHON:-python3}
mkdir -p "$WORK"
echo "== mutation check"
n=0

mutate() {   # NAME FILE DESCRIPTION FROM TO
    d="$WORK/$1"
    rm -rf "$d"
    mkdir -p "$d/src"
    cp "$ROOT"/src/*.sv "$d/src/"
    "$PY" - "$d/src/$2" "$4" "$5" <<'PYEOF'
import sys
path, a, b = sys.argv[1:4]
s = open(path).read()
if s.count(a) != 1:
    sys.exit('mutation anchor not found exactly once: %r' % a)
open(path, 'w').write(s.replace(a, b))
PYEOF
    if EGA_SRC="$d/src" EGA_WORK_DIR="$d" EGA_NO_COVERAGE_GATE=1 EGA_SKIP_BIOS=1 \
        sh "$ROOT/scripts/run_sim.sh" 4 300 >"$d.log" 2>&1; then
        echo "FAIL: mutant $1 ($3) survived"
        exit 1
    fi
    # A kill must be a behavioral difference, not a build or tool error.
    why=$(grep -m1 -E '^FAIL: RTL differs' "$d.log" || true)
    if [ -z "$why" ]; then
        echo "FAIL: mutant $1 stopped the flow without a behavioral difference:"
        tail -5 "$d.log"
        exit 1
    fi
    n=$((n + 1))
    echo "killed $1: $3 -- $(echo "$why" | sed "s#$WORK/##" | cut -c1-90)"
}

mutate m1_fn_and_is_or ega_graphics_ctrl.sv "write path: function AND acts as OR" \
    "2'd1: v = v & lat;" "2'd1: v = v | lat;"
mutate m2_no_bit_mask ega_graphics_ctrl.sv "write path: bit mask ignored" \
    "v = (v & regs[8]) | (lat & ~regs[8]);" "v = v;"
mutate m3_setreset_plane ega_graphics_ctrl.sv "write path: set/reset uses the enable bit as value" \
    "else if (fbit(regs[1], pos, q)) v = {8{fbit(regs[0], pos, q)}};" \
    "else if (fbit(regs[1], pos, q)) v = {8{fbit(regs[1], pos, q)}};"
mutate m4_compare_inverted ega_graphics_ctrl.sv "read path: colour compare result inverted" \
    "cmp0 = fbit(regs[7], pos, 1'b0) ? ~(rd0 ^" "cmp0 = fbit(regs[7], pos, 1'b0) ? (rd0 ^"
mutate m5_oddeven_read ega_graphics_ctrl.sv "read path: odd/even read ignores A0" \
    "plane = regs[5][4] ? {regs[4][2:1], a0} : regs[4][2:0];" "plane = regs[4][2:0];"
mutate m6_htotal ega_crtc.sv "CRTC timing: horizontal total + 3 characters" \
    "assign hc_n = (hc == {1'b0, regs[0]} + 9'd1)" "assign hc_n = (hc == {1'b0, regs[0]} + 9'd2)"
mutate m7_vretrace_end ega_crtc.sv "CRTC timing: vertical retrace end compared on 5 bits" \
    "(vs_line && (vc_n[3:0] != regs[5'h11][3:0]))" "(vs_line && (vc_n[4:0] != regs[5'h11][4:0]))"
mutate m8_line_compare ega_crtc.sv "CRTC: line compare restarts at the start address" \
    "rs_row_n = 16'd0;                      // ASSUMPTION E14" "rs_row_n = start_addr;"
mutate m9_bg_intensity ega_attribute_ctrl.sv "attribute path: blink enable keeps background bit 3" \
    "bg = mode[3] ? {1'b0, at[6:4]} : at[7:4];" "bg = at[7:4];"
mutate m10_plane_enable ega_attribute_ctrl.sv "attribute path: colour plane enable not applied" \
    "pidx = pidx & cpe[3:0];" "pidx = pidx;"
mutate m11_pan9 ega_attribute_ctrl.sv "attribute path: 9-dot panning without the 8,0,1.. order" \
    "sh = (pan >= 4'd8) ? 5'd0 : {1'b0, pan} + 5'd1;" "sh = {1'b0, pan};"
mutate m12_io_a10 ega_io_decode.sv "I/O decode: A10 decoded (no 400h aliases)" \
    "assign u16 = !aen && a[9] && (p3 ? a[8] : !a[8]);" "assign u16 = !aen && a[9] && !a[10] && (p3 ? a[8] : !a[8]);"
mutate m13_isr1_alias ega_io_decode.sv "I/O decode: Input Status 1 also at 3xB" \
    "io_xa     = u16 && (lo == (xb | 8'h0A));" "io_xa     = u16 && (lo[7:1] == (xb[7:1] | 7'h05));"
mutate m14_oddeven_write ega_sequencer.sv "write path: odd/even plane select inverted" \
    "(cpu_off[0] ? 4'b1010 : 4'b0101)" "(cpu_off[0] ? 4'b0101 : 4'b1010)"
echo "PASS: $n of $n mutants killed"
