#!/bin/sh
# Mutation check: plant faults in copies of the RTL and require the
# simulation flow (all directed tests and 4 random seeds, lockstep against
# the model) to show a behavioral difference for each. The original RTL is
# not modified. Mutants m19-m20 concern paths only the ROM's own POST
# exercises; they run the BIOS stages too (VGA_MUT_BIOS=1).
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK=${VGA_WORK_DIR:-$ROOT/work}/mutation
PY=${PYTHON:-python3}
mkdir -p "$WORK"
echo "== mutation check"
n=0

mutate() {   # NAME FILE DESCRIPTION FROM TO [bios]
    d="$WORK/$1"
    rm -rf "$d"
    mkdir -p "$d/src"
    cp "$ROOT"/src/*.sv "$d/src/"
    "$PY" -I - "$d/src/$2" "$4" "$5" <<'PYEOF'
import sys
path, a, b = sys.argv[1:4]
s = open(path).read()
if s.count(a) != 1:
    sys.exit('mutation anchor not found exactly once: %r' % a)
open(path, 'w').write(s.replace(a, b))
PYEOF
    if [ "${6:-}" = bios ]; then skip=""; else skip=1; fi
    if VGA_SRC="$d/src" VGA_WORK_DIR="$d" VGA_NO_COVERAGE_GATE=1 VGA_SKIP_BIOS=$skip \
        sh "$ROOT/scripts/run_sim.sh" 4 300 >"$d.log" 2>&1; then
        echo "FAIL: mutant $1 ($3) survived"
        exit 1
    fi
    why=$(grep -m1 -E '^FAIL: (RTL differs|clk)' "$d.log" || true)
    if [ -z "$why" ]; then
        echo "FAIL: mutant $1 stopped the flow without a behavioral difference:"
        tail -5 "$d.log"
        exit 1
    fi
    n=$((n + 1))
    echo "killed $1: $3 -- $(echo "$why" | sed "s#$WORK/##" | cut -c1-90)"
}

mutate m1_fn_and_is_or vga_graphics_ctrl.sv "write path: function AND acts as OR" \
    "2'd1: v = v & l;" "2'd1: v = v | l;"
mutate m2_wm3_mask vga_graphics_ctrl.sv "write mode 3: rotated data not ANDed into the mask" \
    "m = regs[8] & rot;" "m = regs[8];"
mutate m3_compare_inverted vga_graphics_ctrl.sv "read mode 1: Don't Care sense inverted" \
    "if (regs[7][n]) cmp = cmp" "if (!regs[7][n]) cmp = cmp"
mutate m4_c256_order vga_graphics_ctrl.sv "256-colour serializer: low nibble first" \
    "o[4*j +: 4] = (j % 2 == 0) ? by[7:4] : by[3:0];" "o[4*j +: 4] = (j % 2 == 0) ? by[3:0] : by[7:4];"
mutate m5_chain4_paddr vga_sequencer.sv "chain 4: plane address keeps A1-A0" \
    "if (chain4)     cpu_paddr = {cpu_off[15:2], cpu_off[15:14]};" "if (chain4)     cpu_paddr = cpu_off[15:0];"
mutate m6_htotal vga_crtc.sv "CRTC: HT+4 characters per line" \
    "(hc == {1'b0, regs[0]} + 9'd4)" "(hc == {1'b0, regs[0]} + 9'd3)"
mutate m7_protect vga_crtc.sv "CRTC: Protect bit ignored" \
    "if (regs[5'h11][7] && idx <= 5'd7) begin" "if (1'b0) begin"
mutate m8_double_scan vga_crtc.sv "CRTC: double scan ignored" \
    "rs_tick = !regs[9][7] || dphase;" "rs_tick = 1'b1;"
mutate m9_vbe_bits vga_crtc.sv "CRTC: vertical blank end compared on 5 bits" \
    "(vb_q && (vc_n[7:0] != regs[5'h16]))" "(vb_q && (vc_n[4:0] != regs[5'h16][4:0]))"
mutate m10_dword vga_crtc.sv "CRTC: doubleword address without MA13-12 in bits 1-0" \
    "disp_addr = {ma[13:0], ma[13:12]};" "disp_addr = {ma[13:0], 2'b00};"
mutate m11_pel_width vga_attribute_ctrl.sv "attribute: PEL width pairs swapped" \
    "dac_addr = {p0[3:0], p1};" "dac_addr = {p1, p0[3:0]};"
mutate m12_io_a10 vga_io_decode.sv "I/O decode: A10 decoded (no 400h aliases)" \
    "assign io  = !aen && enable && (a[9:8] == 2'b11);" "assign io  = !aen && enable && !a[10] && (a[9:8] == 2'b11);"
mutate m13_enable_pos vga_general_regs.sv "card enable ignores POS 102h" \
    "assign enable = vse[3] && pos;" "assign enable = vse[3];"
mutate m14_dac_order vga_dac.sv "DAC: read returns green first" \
    "2'd0:    rd_data = {2'b00, cpu_q[17:12]};" "2'd0:    rd_data = {2'b00, cpu_q[11:6]};"
mutate m15_pelmask vga_dac.sv "DAC: PEL mask not applied" \
    "assign pix_q   = mem[pix_addr & pelmask];" "assign pix_q   = mem[pix_addr];"
mutate m16_colsel vga_attribute_ctrl.sv "attribute: Color Select bits 3-2 not used for P7-P6" \
    "else                   dac_addr = {colsel[3:2]," "else                   dac_addr = {2'b00,"
mutate m17_text_depth ibm_vga.sv "pipeline: alphanumeric depth equal to graphics (V14)" \
    "base = text ? 3'd3 : 3'd2;" "base = 3'd2;"
mutate m18_sense vga_dac.sv "switch sense: open outputs not doubled" \
    "e = ld ? {1'b0, v} : {v, 1'b0};" "e = {1'b0, v};"
mutate m19_status_mux ibm_vga.sv "Input Status 1 bits 5-4 always 0 (the V16 defect)" \
    "assign isr1 = {2'b00, diag, vs_line, 2'b00, !de_out};" "assign isr1 = {4'h0, vs_line, 2'b00, !de_out};"
mutate m20_attr_3c1 vga_io_decode.sv "I/O decode: 3C1 also accepts attribute writes" \
    "io_attr     = io && (lo == 8'hC0);" "io_attr     = io && (lo[7:1] == 7'h60);"
echo "PASS: $n of $n mutants killed"
