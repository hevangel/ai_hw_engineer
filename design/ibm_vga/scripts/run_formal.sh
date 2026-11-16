#!/bin/sh
# SymbiYosys: unbounded proofs (abc pdr) and covers (smtbmc yices) for the
# video DAC, the graphics controller, the CRT controller and the card top
# (plane RAM and ROM black-boxed). Then a planted fault per proof must make
# that proof fail. See plans/formal_plan.md.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${VGA_WORK_DIR:-$ROOT/work}
mkdir -p "$WORK/formal"
echo "== formal"
cd "$ROOT/formal"
for f in vga_dac vga_graphics_ctrl vga_crtc ibm_vga; do
    start=$(date +%s)
    sby -f --prefix "$WORK/formal/$f" "$f.sby" >"$WORK/formal/$f.log" 2>&1 || {
        tail -40 "$WORK/formal/$f.log"; exit 1; }
    nc=$(grep -c 'reached cover statement' "$WORK/formal/$f.log" || true)
    echo "$f: prove PASS, cover $nc reached ($(( $(date +%s) - start )) s)"
done

# Each proof must fail with a planted fault (the properties are not vacuous).
neg() {   # NAME FILE SBY TASK FROM TO
    d="$WORK/formal/neg_$1"
    rm -rf "$d"
    mkdir -p "$d/src" "$d/formal"
    cp "$ROOT"/src/*.sv "$d/src/"
    cp "$ROOT/formal/$3.sby" "$d/formal/"
    python3 -I - "$d/src/$2" "$5" "$6" <<'PYEOF'
import sys
path, a, b = sys.argv[1:4]
s = open(path).read()
if s.count(a) != 1:
    sys.exit('anchor not found exactly once: %r' % a)
open(path, 'w').write(s.replace(a, b))
PYEOF
    if (cd "$d/formal" && sby -f --prefix "$d/run" "$3.sby" "$4" >"$d.log" 2>&1); then
        echo "FAIL: planted fault $1 not detected by $3 $4"
        exit 1
    fi
    grep -q 'Assert failed\|FAIL' "$d.log" || { echo "FAIL: $1: no assertion failure"; tail -5 "$d.log"; exit 1; }
    echo "planted fault $1: $3 $4 fails as required"
}
neg dac_sub vga_dac.sv vga_dac prove "if (sub == 2'd2) begin" "if (sub == 2'd3) begin"
neg gc_wm3 vga_graphics_ctrl.sv vga_graphics_ctrl prove "m = regs[8] & rot;" "m = regs[8];"
neg crtc_hend vga_crtc.sv vga_crtc prove_h "(hs_q && (hc[4:0] != regs[5][4:0]))" "(hs_q && (hc[3:0] != regs[5][3:0]))"
neg crtc_vend vga_crtc.sv vga_crtc prove_v "(vs_line && (vc_n[3:0] != regs[5'h11][3:0]))" "(vs_line && (vc_n[4:0] != regs[5'h11][4:0]))"
neg top_setup_dac vga_io_decode.sv ibm_vga prove "assign dac = io && !setup;" "assign dac = io;"
echo "PASS: formal prove and cover; 5 planted faults detected"
