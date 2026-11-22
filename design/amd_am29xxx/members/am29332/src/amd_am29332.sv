// AMD Am29332 32-bit non-cascadable ALU/shift register, cycle-accurate
// digital model.
//
// Sources: AMD Am29332 Instruction Manual (1987, 07995A) Chapter 1 summary
// tables and Figure 3 status map, Chapter 2 per-instruction descriptions,
// Appendix A BCD rules, Appendix B modified-Booth multiply and nonrestoring
// divide flow charts with worked traces (65hx48h = 1C68h; 75h/02h = 3Ah rem
// 01h), and the Am29332 datasheet PIN DESCRIPTION section in the 1988 data
// book (signal-level BOROW/RS/HOLD/M/m semantics). See spec/spec.md for the
// full contract and the assumption ledger.
//
// The datapath is combinational; the status and Q registers clock on CP
// rising edges and freeze on HOLD. There is no reset pin: the part powers up
// with the registers undefined and initializes via LDSTAT; this model
// defines an all-zero power-up state (spec ledger). Y is driven when OE-Y is
// low in master mode; the *_ext inputs carry the wire values that the
// slave/master diagnostic comparators check against the internal results
// (the Y-bus three-state buffer itself is external to this model, per the
// y_o/y_oe_o pad-split convention used across this series).

// The datapath intentionally mixes 32-bit operands with the 33-bit extended
// divide adder and the 34-bit modified-Booth ALU; Verilator's WIDTH warnings
// are waived at module scope for that reason. All functional widths are
// checked by the lockstep simulation and formal properties.
/* verilator lint_off WIDTH */
// UNUSEDSIGNAL: wide function temporaries whose unused upper bits are the
// natural byproduct of shared adder/rotate helpers. MULTIDRIVEN: the initial
// block sets the modeled power-up state (the part has no reset pin).
/* verilator lint_off UNUSEDSIGNAL */
/* verilator lint_off MULTIDRIVEN */
module amd_am29332 (
    input  logic        cp_i,
    input  logic        hold_i,
    input  logic        borow_i,     // borrow mode
    input  logic        macro_i,     // M/m: 1 = macro MCIN/MLINK, 0 = micro C/L
    input  logic        mlink_i,
    input  logic        mcin_i,
    input  logic        rs_i,        // register-status output select
    input  logic        slave_i,
    input  logic        oey_n_i,
    input  logic [31:0] da_i,
    input  logic [31:0] db_i,
    input  logic [3:0]  pa_i,
    input  logic [3:0]  pb_i,
    input  logic [8:0]  instr_i,     // I8..I0
    input  logic [5:0]  p_i,         // position
    input  logic [4:0]  w_i,         // width
    input  logic [31:0] y_ext_i,     // wire value for slave/master compare
    input  logic [3:0]  py_ext_i,
    input  logic [4:0]  cznvl_ext_i, // {C,Z,N,V,L} wire value
    input  logic        perr_ext_i,
    output logic [31:0] y_o,
    output logic        y_oe_o,
    output logic [3:0]  py_o,
    output logic [4:0]  cznvl_o,     // {C,Z,N,V,L}
    output logic        perr_o,
    output logic        mserr_o
`ifdef FORMAL
    ,
    output logic [31:0] stat_o,
    output logic [31:0] q_o
`endif
);

  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------
  logic [31:0] status_q;
  logic [31:0] q_q;

`ifdef FORMAL
  assign stat_o = status_q;
  assign q_o = q_q;
`endif

  // ------------------------------------------------------------------
  // Decode
  // ------------------------------------------------------------------
  logic [6:0] opcode;
  logic [1:0] bwc;            // byte-width code (FORMAT 1)
  logic       psel, wsel;     // FORMAT 2 position/width source selects

  assign opcode = instr_i[6:0];
  assign bwc    = instr_i[8:7];
  assign psel   = instr_i[8];
  assign wsel   = instr_i[7];

  function automatic logic [31:0] selmask(input logic [1:0] code);
    case (code)
      2'b01:   selmask = 32'h000000FF;
      2'b10:   selmask = 32'h0000FFFF;
      2'b11:   selmask = 32'h00FFFFFF;
      default: selmask = 32'hFFFFFFFF;
    endcase
  endfunction

  function automatic int unsigned bwid(input logic [1:0] code);
    case (code)
      2'b01:   bwid = 8;
      2'b10:   bwid = 16;
      2'b11:   bwid = 24;
      default: bwid = 32;
    endcase
  endfunction

  function automatic logic [31:0] rotl32(input logic [31:0] v,
                                         input int unsigned n);
    if (n == 0 || n == 32) rotl32 = v;
    else rotl32 = (v << n) | (v >> (32 - n));
  endfunction

  function automatic logic [31:0] rotr32(input logic [31:0] v,
                                         input int unsigned n);
    if (n == 0 || n == 32) rotr32 = v;
    else rotr32 = rotl32(v, 32 - n);
  endfunction

  // field mask from bit pos over wbits (0 -> [pos:31]), truncated at bit 31
  function automatic logic [31:0] fmask(input int unsigned pos,
                                        input int unsigned wbits);
    int unsigned ww;
    ww = (wbits == 0) ? (32 - pos) : wbits;
    if (ww > (32 - pos)) ww = 32 - pos;
    fmask = (ww == 0) ? 32'h0 : (((32'h1 << ww) - 1) << pos);
  endfunction

  // {carry_out, carry_into_msb, sum}
  function automatic logic [33:0] wadd(input logic [31:0] x,
                                       input logic [31:0] y2,
                                       input logic        cin,
                                       input int unsigned bits);
    logic [33:0] mask, xq, yq, tq, lq;
    mask = (34'h1 << bits) - 1;
    xq = 34'(x) & mask;
    yq = 34'(y2) & mask;
    tq = xq + yq + 34'(cin);
    lq = ((xq & (mask >> 1)) + (yq & (mask >> 1)) + 34'(cin)) >> (bits - 1);
    wadd = {tq[bits], lq[0], tq[31:0]};
  endfunction

  // BCD nibble carries over the full 32-bit add (Appendix A rules 1 and 2).
  // Nibble operands go through explicit temporaries: an inline
  // 5'(~y[4*i +: 4]) expression mis-compiles under Verilator 5.052.
  function automatic logic [7:0] nib_carries_add(input logic [31:0] x,
                                                 input logic [31:0] y2,
                                                 input logic        cin);
    logic [7:0] nc;
    logic [7:0] bcout;
    logic [4:0] s;
    logic [3:0] xa, ya;
    logic       c;
    c = cin;
    nc = 8'h0;
    bcout = 8'h0;
    for (int i = 0; i < 8; i++) begin
      xa = x[4*i +: 4];
      ya = y2[4*i +: 4];
      s = 5'(xa) + 5'(ya) + 5'(c);
      bcout[i] = s[4];
      nc[i] = (s > 5'd9);
      if (i > 0) begin
        nc[i] = nc[i] | ((s == 5'd9) && nc[i-1] && !bcout[i-1]);
      end
      c = s[4];
    end
    nib_carries_add = nc;
  endfunction

  // nibble borrows = complement of the binary inter-nibble carries of a-b
  function automatic logic [7:0] nib_borrows_sub(input logic [31:0] x,
                                                 input logic [31:0] y2,
                                                 input logic        cin);
    logic [7:0] nb;
    logic [4:0] s;
    logic [3:0] xa, ya;
    logic       c;
    c = cin;
    for (int i = 0; i < 8; i++) begin
      xa = x[4*i +: 4];
      ya = ~y2[4*i +: 4];
      s = 5'(xa) + 5'(ya) + 5'(c);
      c = s[4];
      nb[i] = !c;
    end
    nib_borrows_sub = nb;
  endfunction

  // Read-only relational bits (15:13) and bit 23 are combinational
  // functions of the stored flags (bit 13 also of the current BOROW pin):
  // the register cells do not exist (EXTBIT-STAT note 2, PASS-STAT note 1).
  // Every readout of the status register presents these values.
  function automatic logic [31:0] stat_comb(input logic [31:0] st,
                                            input logic        brw);
    logic s13, s14, s15;
    s13 = (brw ? !st[16] : st[16]) | st[19];
    s14 = st[17] ^ st[18];
    s15 = s14 | st[19];
    stat_comb = (st & ~(32'h0000_E000 | 32'h0080_0000)) | (s15 << 15)
                | (s14 << 14) | (s13 << 13);
  endfunction

  // ------------------------------------------------------------------
  // Combinational datapath
  // ------------------------------------------------------------------
  logic [31:0] a, b;
  logic [31:0] sel;
  int unsigned bw;
  logic        cin_sel, link_sel;

  logic [31:0] y_d;
  logic [31:0] q_d;
  logic        f_c, f_z, f_n, f_v, f_l, f_m, f_s;
  logic        u_c, u_z, u_n, u_v, u_l, u_m, u_s;
  logic [7:0]  nc_d;
  logic        nc_wen;
  logic [31:0] stat_wdat;
  logic [31:0] stat_wmask;
  logic        prior_wen;
  logic [4:0]  prior_val;
  logic        statbit_wen;
  logic [4:0]  statbit_idx;
  logic        statbit_val;

  logic [31:0] stat_next;
  logic [31:0] y_res;
  logic [3:0]  py_res;
  logic        perr_res;
  logic [4:0]  flag_pins;
  logic        cmp_y_act;

  assign a = da_i;
  assign b = db_i;
  assign sel = selmask(bwc);
  assign bw = unsigned'(bwid(bwc));
  assign cin_sel = macro_i ? mcin_i : status_q[16];
  assign link_sel = macro_i ? mlink_i : status_q[20];

  always_comb begin
    logic [31:0] src, f, m, src2, srcs, xop, xs, k;
    logic [33:0] t;
    logic [31:0] s32, corr;
    logic [7:0]  ncb;
    logic        cout_w, cin_msb, rem_sign, qbit, divsign, cond, psgn;
    logic [31:0] q_sel, bext;
    logic [32:0] op2, fsum, bext33;
    logic        cout9;
    int unsigned msbn_i;
    logic [4:0]  pu;
    logic        psgn_b;
    logic [5:0]  w5v;
    int unsigned shamt, pv;
    logic [31:0] pval;
    logic [1:0]  q10;
    logic [33:0] astar, bstar, fstar;
    logic        fill;
    logic        dvar;
    logic [31:0] statc;
    logic [31:0] a_sel;
    logic [31:0] b_sel;
    logic        a_sel_msb;
    logic        b_sel_msb;

    y_d = b;
    q_d = q_q;
    f_c = status_q[16]; f_z = status_q[19]; f_n = status_q[17];
    f_v = status_q[18]; f_l = status_q[20]; f_m = status_q[21];
    f_s = status_q[22];
    u_c = 1'b0; u_z = 1'b0; u_n = 1'b0; u_v = 1'b0;
    u_l = 1'b0; u_m = 1'b0; u_s = 1'b0;
    nc_d = status_q[31:24];
    nc_wen = 1'b0;
    stat_wdat = 32'h0;
    stat_wmask = 32'h0;
    prior_wen = 1'b0;
    prior_val = 5'h0;
    statbit_wen = 1'b0;
    statbit_idx = 5'h0;
    statbit_val = 1'b0;
    q_sel = q_q & sel;
    a_sel = a & sel;
    b_sel = b & sel;
    a_sel_msb = a_sel[bw-1];
    b_sel_msb = b_sel[bw-1];
    src = 32'h0; f = 32'h0; m = 32'h0; src2 = 32'h0; srcs = 32'h0;
    xop = 32'h0; xs = 32'h0; k = 32'h0;
    t = 34'h0; s32 = 32'h0; corr = 32'h0; ncb = 8'h0;
    cout_w = 1'b0; cin_msb = 1'b0; rem_sign = 1'b0; qbit = 1'b0;
    divsign = 1'b0; cond = 1'b0; psgn = 1'b0;
    bext = 32'h0; op2 = 33'h0;
    fsum = 33'h0; bext33 = 33'h0; cout9 = 1'b0;
    msbn_i = 0;
    pu = 5'h0; psgn_b = 1'b0; w5v = 6'h0; shamt = 0; pv = 0;
    pval = 32'h0;
    q10 = 2'b00;
    astar = 34'h0; bstar = 34'h0; fstar = 34'h0;
    fill = 1'b0;
    dvar = 1'b0;
    statc = 32'h0;

    unique case (opcode)
    // ---------------- data movement ----------------
    7'h00, 7'h01: begin  // ZERO-EXTA/B
      src = (opcode == 7'h00) ? a : b;
      y_d = src;
      u_z = 1'b1; f_z = (y_d == 32'h0);
      u_n = 1'b1; f_n = src[bw-1];
    end
    7'h02, 7'h03: begin  // SIGN-EXTA/B
      src = (opcode == 7'h02) ? a : b;
      y_d = (src & sel) | (src[bw-1] ? ~sel : 32'h0);
      u_z = 1'b1; f_z = (y_d == 32'h0);
      u_n = 1'b1; f_n = src[bw-1];
    end
    7'h04: y_d = (stat_comb(status_q, borow_i) & sel) | (b & ~sel);  // PASS-STAT
    7'h05: y_d = (q_q & sel) | (b & ~sel);       // PASS-Q
    7'h06, 7'h07: begin  // LOADQ-A/B
      src = (opcode == 7'h06) ? a : b;
      q_d = (q_q & ~sel) | (src & sel);
      y_d = (src & sel) | (q_q & ~sel);
      u_z = 1'b1; f_z = ((src & sel) == 32'h0);
      u_n = 1'b1; f_n = src[bw-1];
    end
    7'h08, 7'h09: begin  // NOT-A/B
      src = (opcode == 7'h08) ? a : b;
      y_d = (src & ~sel) | (~src & sel);
      u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
      u_n = 1'b1; f_n = y_d[bw-1];
    end
    7'h0C, 7'h0D: begin  // PRIOR-A/B
      src = (opcode == 7'h0C) ? a : b;
      f = src & sel;
      y_d = 32'h0;
      // f is zero above the selected bytes, so a constant bound (yosys
      // requires constant procedural loop bounds) with the bw-based count
      // is equivalent to scanning only the selected bytes
      for (int i = 0; i < 32; i++) begin
        if (f[i]) y_d = 32'(bw - 1 - i);
      end
      u_z = 1'b1; f_z = (f == 32'h0);
      prior_wen = 1'b1;
      prior_val = y_d[4:0];
    end
    7'h0E, 7'h0F: begin  // MERGEA-B / MERGEB-A
      src = (opcode == 7'h0E) ? a : b;
      y_d = (opcode == 7'h0E) ? ((b & ~sel) | (src & sel))
                              : ((a & ~sel) | (src & sel));
      u_z = 1'b1; f_z = ((src & sel) == 32'h0);
      u_n = 1'b1; f_n = src[bw-1];
    end
    7'h1C, 7'h1D: begin  // LDSTAT-A/B
      src = (opcode == 7'h1C) ? a : b;
      stat_wdat = src;
      stat_wmask = sel;
      y_d = (stat_comb(status_q, borow_i) & ~sel) | (src & sel);
    end
    // ---------------- single-bit shifts ----------------
    7'h20, 7'h21, 7'h22, 7'h23, 7'h24, 7'h25, 7'h26, 7'h27,
    7'h28, 7'h29, 7'h2A, 7'h2B, 7'h2C, 7'h2D, 7'h2E, 7'h2F,
    7'h30, 7'h31, 7'h32, 7'h33, 7'h34, 7'h35, 7'h36, 7'h37,
    7'h38, 7'h39, 7'h3A, 7'h3B: begin
      src = opcode[0] ? b : a;
      src2 = src & sel;
      dvar = opcode[1];       // *Q double-precision variants have bit1 set
      if (!opcode[4]) begin  // downshifts: 0x20-0x2F (bit4=0)
        case (opcode[3:2])
          2'b00:   fill = 1'b0;
          2'b01:   fill = 1'b1;
          2'b10:   fill = link_sel;
          default: fill = src2[bw-1];
        endcase
        y_d = (src & ~sel) | ((src2 >> 1) | (32'(fill) << (bw-1)));
        if (dvar) begin
          q_d = (q_q & ~sel) | ((q_sel >> 1) | (32'(src2[0]) << (bw-1)));
          u_l = 1'b1; f_l = q_sel[0];
        end else begin
          u_l = 1'b1; f_l = src2[0];
        end
      end else begin  // upshifts
        case (opcode[3:2])
          2'b00:   fill = 1'b0;
          2'b01:   fill = 1'b1;
          default: fill = link_sel;
        endcase
        y_d = (src & ~sel) | (((src2 << 1) & sel) | 32'(fill));
        if (dvar) begin
          q_d = (q_q & ~sel) | (((q_sel << 1) & sel) | 32'(fill));
        end
        u_l = 1'b1; f_l = src2[bw-1];
        u_v = 1'b1; f_v = src2[bw-1] ^ y_d[bw-1];
      end
      u_n = 1'b1; f_n = y_d[bw-1];
      u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
    end
    // ---------------- logical ----------------
    7'h3C: begin  // ZERO
      y_d = b & ~sel;
      u_z = 1'b1; f_z = 1'b1;
      u_n = 1'b1; f_n = 1'b0;
    end
    7'h3D: begin  // SIGN
      y_d = (b & ~sel) | (status_q[17] ? sel : 32'h0);
      u_z = 1'b1; f_z = !status_q[17];
    end
    7'h3E, 7'h3F, 7'h40, 7'h41: begin  // OR XOR AND XNOR
      case (opcode[1:0])
        2'b10:   f = a | b;
        2'b11:   f = a ^ b;
        2'b00:   f = a & b;
        default: f = ~(a ^ b);
      endcase
      y_d = (b & ~sel) | (f & sel);
      u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
      u_n = 1'b1; f_n = y_d[bw-1];
    end
    // ---------------- NEG ----------------
    7'h0A, 7'h0B: begin
      src = (opcode == 7'h0A) ? a : b;
      t = wadd(32'h0, ~src, 1'b1, 32);
      s32 = t[31:0];
      ncb = nib_borrows_sub(32'h0, src, 1'b1);
      t = wadd(32'h0, ~src, 1'b1, bw);
      y_d = (src & ~sel) | (s32 & sel);
      u_c = 1'b1; f_c = t[33] ^ borow_i;
      u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
      u_n = 1'b1; f_n = y_d[bw-1];
      u_v = 1'b1; f_v = t[32] ^ t[33];
      nc_d = ncb; nc_wen = 1'b1;
    end
    // ---------------- INCR / DECR ----------------
    7'h10, 7'h11, 7'h12, 7'h13, 7'h14, 7'h15, 7'h16, 7'h17,
    7'h18, 7'h19, 7'h1A, 7'h1B: begin
      k = opcode[3] ? 32'd4 : (opcode[2] ? 32'd2 : 32'd1);
      src = opcode[0] ? b : a;
      if (opcode[1]) begin  // INCR class (12,13,16,17,1A,1B: bit1 set)
        t = wadd(src, k, 1'b0, 32);
        s32 = t[31:0];
        ncb = nib_carries_add(src, k, 1'b0);
        t = wadd(src, k, 1'b0, bw);
        y_d = (src & ~sel) | (s32 & sel);
        u_c = 1'b1; f_c = t[33];
      end else begin  // DECR class (10,11,14,15,18,19)
        t = wadd(src, ~k, 1'b1, 32);
        s32 = t[31:0];
        ncb = nib_borrows_sub(src, k, 1'b1);
        t = wadd(src, ~k, 1'b1, bw);
        y_d = (src & ~sel) | (s32 & sel);
        u_c = 1'b1; f_c = t[33] ^ borow_i;
      end
      u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
      u_n = 1'b1; f_n = y_d[bw-1];
      u_v = 1'b1; f_v = t[32] ^ t[33];
      nc_d = ncb; nc_wen = 1'b1;
    end
    // ---------------- ADD family ----------------
    7'h42, 7'h43, 7'h44, 7'h45, 7'h46, 7'h47: begin
      if (opcode[2]) begin  // SUB/SUBC/SUBR/SUBRC
        xop = opcode[1] ? b : a;  // minuend (SUBR/SUBRC: bit1)
        xs  = opcode[1] ? a : b;  // subtrahend
        if (opcode[0]) begin  // with carry (inverted on borrow)
          t = wadd(xop, ~xs, cin_sel ^ borow_i, 32);
          s32 = t[31:0];
          ncb = nib_borrows_sub(xop, xs, cin_sel ^ borow_i);
          t = wadd(xop, ~xs, cin_sel ^ borow_i, bw);
        end else begin
          t = wadd(xop, ~xs, 1'b1, 32);
          s32 = t[31:0];
          ncb = nib_borrows_sub(xop, xs, 1'b1);
          t = wadd(xop, ~xs, 1'b1, bw);
        end
        y_d = (b & ~sel) | (s32 & sel);
        u_c = 1'b1; f_c = t[33] ^ borow_i;
      end else begin  // ADD/ADDC
        if (opcode[0]) begin  // ADDC: bit0
          t = wadd(a, b, cin_sel, 32);
          s32 = t[31:0];
          ncb = nib_carries_add(a, b, cin_sel);
          t = wadd(a, b, cin_sel, bw);
        end else begin
          t = wadd(a, b, 1'b0, 32);
          s32 = t[31:0];
          ncb = nib_carries_add(a, b, 1'b0);
          t = wadd(a, b, 1'b0, bw);
        end
        y_d = (b & ~sel) | (s32 & sel);
        u_c = 1'b1; f_c = t[33];
      end
      u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
      u_n = 1'b1; f_n = y_d[bw-1];
      u_v = 1'b1; f_v = t[32] ^ t[33];
      nc_d = ncb; nc_wen = 1'b1;
    end
    // ---------------- BCD corrections ----------------
    7'h48, 7'h49, 7'h4A, 7'h4B: begin
      src = opcode[0] ? b : a;
      corr = 32'h0;
      for (int i = 0; i < 8; i++) begin
        if (status_q[24 + i]) corr[4*i +: 4] = 4'h6;
      end
      msbn_i = bw / 4 - 1;
      if (opcode[1]) begin  // DIFF-CORR
        t = wadd(src, ~corr, 1'b1, 32);
        y_d = (src & ~sel) | (t[31:0] & sel);
        u_c = 1'b1; f_c = !(status_q[24 + msbn_i] ^ borow_i);
      end else begin  // SUM-CORR
        t = wadd(src, corr, 1'b0, 32);
        y_d = (src & ~sel) | (t[31:0] & sel);
        u_c = 1'b1; f_c = status_q[24 + msbn_i];
      end
      u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
      u_n = 1'b1; f_n = y_d[bw-1];
      u_v = 1'b1;
      f_v = status_q[24 + msbn_i] ^ status_q[23 + msbn_i];
    end
    // ---------------- multiply ----------------
    7'h5B, 7'h5C, 7'h5D, 7'h5E, 7'h5F: begin
      q10 = q_sel[1:0];
      if (opcode == 7'h5D) begin  // UMULLAST
        f = status_q[21] ? ((b & sel) + (a & sel)) : (b & sel);
        y_d = (b & ~sel) | (f & sel);
        u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
      end else begin
        if (opcode >= 7'h5E) begin  // SMULSTEP/SMULFIRST sign-extend A
          astar = a_sel_msb ? ((34'h3 << bw) | 34'(a_sel)) : 34'(a_sel);
        end else begin
          astar = 34'(a_sel);
        end
        if (opcode[0]) begin  // FIRST steps 5B/5F (bit0 = 1)
          case (q10)
            2'b01:   fstar = astar;
            2'b10:   fstar = 34'h0 - (astar << 1);
            2'b11:   fstar = 34'h0 - astar;
            default: fstar = 34'h0;
          endcase
        end else begin  // STEP 5C/5E
          bstar = b_sel_msb ? ((34'h3 << bw) | 34'(b_sel)) : 34'(b_sel);
          case ({q_sel[1], q_sel[0], status_q[21]})
            3'b000, 3'b111: fstar = bstar;
            3'b001, 3'b010: fstar = bstar + astar;
            3'b101, 3'b110: fstar = bstar - astar;
            3'b011:         fstar = bstar + (astar << 1);
            default:        fstar = bstar - (astar << 1);
          endcase
        end
        fstar = fstar & ((34'h1 << (bw + 2)) - 1);
        y_d = (b & ~sel) | ((fstar >> 2) & sel);
        q_d = (q_q & ~sel) |
              (((q_sel >> 2) | (32'(fstar[1:0]) << (bw-2))) & sel);
        u_m = 1'b1; f_m = q_sel[1];
      end
    end
    // ---------------- divide ----------------
    7'h4E, 7'h4F, 7'h50, 7'h51, 7'h52, 7'h53, 7'h54, 7'h55,
    7'h56, 7'h57, 7'h58, 7'h59, 7'h5A: begin
      case (opcode)
        7'h4F: begin  // UDIVFIRST
          y_d = (b & ~sel) | (((b & sel) << 1) & sel) | q_sel[bw-1];
          u_l = 1'b1; f_l = b_sel[bw-1];
          q_d = (q_q & ~sel) | ((q_sel << 1) & sel);
          u_m = 1'b1; f_m = 1'b1;
          u_s = 1'b1; f_s = 1'b0;
          u_n = 1'b1; f_n = y_d[bw-1];
          u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
        end
        7'h4E: begin  // SDIVFIRST
          qbit = !(a_sel[bw-1] ^ b_sel[bw-1]);
          y_d = (b & ~sel) | ((((b & sel) << 1) & sel) | q_sel[bw-1]);
          u_l = 1'b1; f_l = b_sel[bw-1];
          u_s = 1'b1; f_s = b_sel[bw-1];
          q_d = (q_q & ~sel) | (((q_sel << 1) & sel) | qbit);
          u_m = 1'b1; f_m = qbit;
          u_n = 1'b1; f_n = y_d[bw-1];
          u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
        end
        7'h54, 7'h55: begin  // UDIVSTEP / UDIVLAST
          bext33 = (status_q[22] ? (33'h1 << bw) : 33'h0) | 33'(b & sel);
          op2 = status_q[21] ? ((33'h1 << bw) | 33'((~a) & sel))
                             : 33'(a & sel);
          t = 34'(bext33) + 34'(op2) + 34'(cin_sel);
          fsum = t[32:0] & ((33'h1 << (bw + 1)) - 1);
          cout9 = t[bw+1];
          qbit = !fsum[bw];
          rem_sign = fsum[bw-1];
          if (opcode == 7'h54) begin
            y_d = (b & ~sel) | (((fsum << 1) & sel) | q_sel[bw-1]);
            u_l = 1'b1; f_l = rem_sign;
            u_s = 1'b1; f_s = rem_sign;
            u_n = 1'b1; f_n = y_d[bw-1];
          end else begin
            y_d = (b & ~sel) | (fsum & sel);
            u_s = 1'b1; f_s = 1'b0;
            u_n = 1'b1; f_n = fsum[bw];
          end
          q_d = (q_q & ~sel) | (((q_sel << 1) & sel) | qbit);
          u_m = 1'b1; f_m = qbit;
          u_c = 1'b1; f_c = cout9;
          u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
        end
        7'h50, 7'h51: begin  // SDIVSTEP / SDIVLAST1
          op2 = status_q[21] ? ((~a) & sel) : (a & sel);
          t = 34'(b & sel) + 34'(op2) + 34'(status_q[21]);
          fsum = 33'(t) & ((33'h1 << (bw + 1)) - 1);
          rem_sign = fsum[bw-1];
          qbit = !(a_sel[bw-1] ^ rem_sign);
          if (opcode == 7'h50) begin
            y_d = (b & ~sel) | (((fsum << 1) & sel) | q_sel[bw-1]);
            u_l = 1'b1; f_l = rem_sign;
            q_d = (q_q & ~sel) | (((q_sel << 1) & sel) | qbit);
            u_m = 1'b1; f_m = qbit;
            u_c = 1'b1; f_c = t[bw];
            u_n = 1'b1; f_n = y_d[bw-1];
            u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
          end else begin
            y_d = (b & ~sel) | (fsum & sel);
            q_d = (q_q & ~sel) | (((q_sel << 1) & sel) | 32'(1'b1));
            u_m = 1'b1; f_m = qbit;
            u_c = 1'b1; f_c = t[bw];
            u_n = 1'b1; f_n = rem_sign;
            u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
          end
        end
        7'h5A: begin  // SDIVLAST2
          divsign = q_sel[bw-1];
          op2 = divsign ? ((~a) & sel) : (a & sel);
          t = 34'(b & sel) + 34'(op2) + 34'(divsign);
          y_d = (b & ~sel) | (t[31:0] & sel);
          u_z = 1'b1;
          f_z = status_q[22] ? ((t[31:0] & sel) == 32'h0) : 1'b0;
        end
        7'h52: begin  // MPDIVSTEP1 (full word, no carry-in)
          op2 = status_q[21] ? (~a) : a;
          t = 34'(b) + 34'(op2) + 34'(status_q[21]);
          y_d = (t[31:0] << 1) | q_sel[bw-1];
          u_l = 1'b1; f_l = t[31];
          u_c = 1'b1; f_c = t[32];
          q_d = (q_q & ~sel) | ((q_sel << 1) & sel);
          u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
        end
        7'h56: begin  // MPDIVSTEP2 (full word, with carry-in)
          op2 = status_q[21] ? (~a) : a;
          t = 34'(b) + 34'(op2) + 34'(cin_sel);
          y_d = (t[31:0] << 1) | 32'(status_q[20]);
          u_l = 1'b1; f_l = t[31];
          u_c = 1'b1; f_c = t[32];
          u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
        end
        7'h53: begin  // MPSDIVSTEP3
          op2 = status_q[21] ? ((~a) & sel) : (a & sel);
          t = 34'(b & sel) + 34'(op2) + 34'(cin_sel);
          fsum = 33'(t);
          rem_sign = fsum[bw-1];
          qbit = !(a_sel[bw-1] ^ rem_sign);
          y_d = (b & ~sel) | (((fsum << 1) & sel) | 32'(status_q[20]));
          u_l = 1'b1; f_l = rem_sign;
          q_d = (q_q & 32'hFFFFFFFE) | 32'(qbit);
          u_m = 1'b1; f_m = qbit;
          u_c = 1'b1; f_c = t[bw];
          u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
        end
        7'h57: begin  // MPUDIVSTP3
          bext33 = (status_q[22] ? (33'h1 << bw) : 33'h0) | 33'(b & sel);
          op2 = status_q[21] ? ((33'h1 << bw) | 33'((~a) & sel))
                             : 33'(a & sel);
          t = 34'(bext33) + 34'(op2) + 34'(cin_sel);
          fsum = t[32:0] & ((33'h1 << (bw + 1)) - 1);
          cout9 = t[bw+1];
          qbit = status_q[21] ^ status_q[22] ^ cout9;
          rem_sign = fsum[bw-1];
          y_d = (b & ~sel) | (((fsum << 1) & sel) | 32'(status_q[20]));
          u_l = 1'b1; f_l = rem_sign;
          u_s = 1'b1; f_s = rem_sign;
          q_d = (q_q & 32'hFFFFFFFE) | 32'(qbit);
          u_m = 1'b1; f_m = qbit;
          u_c = 1'b1; f_c = cout9;
          u_z = 1'b1; f_z = ((y_d & sel) == 32'h0);
        end
        7'h58: begin  // REMCORR: gate Z^N^S, direction M
          cond = status_q[19] ^ status_q[17] ^ status_q[22];
          if (cond) begin
            op2 = status_q[21] ? ((~a) & sel) : (a & sel);
            t = 34'(b & sel) + 34'(op2) + 34'(status_q[21]);
            y_d = (b & ~sel) | (t[31:0] & sel);
            u_c = 1'b1; f_c = t[bw];
          end else begin
            y_d = (b & ~sel) | (b & sel);
            u_c = 1'b1; f_c = 1'b0;
          end
        end
        default: begin  // 7'h59 QUOCORR: gate Z^N^S, direction M
          cond = status_q[19] ^ status_q[17] ^ status_q[22];
          if (cond) begin
            if (status_q[21]) begin
              t = wadd(b & sel, 32'h1, 1'b0, bw);
            end else begin
              t = wadd(b & sel, sel - 1, 1'b1, bw);
            end
            y_d = (b & ~sel) | (t[31:0] & sel);
            u_c = 1'b1; f_c = t[33];
            u_v = 1'b1; f_v = t[32] ^ t[33];
          end else begin
            y_d = (b & ~sel) | (b & sel);
            u_c = 1'b1; f_c = 1'b0;
            u_v = 1'b1; f_v = 1'b0;
          end
        end
      endcase
    end
    // ---------------- N-bit shifts / rotates ----------------
    7'h60, 7'h61, 7'h62, 7'h63, 7'h64, 7'h65: begin
      src = a;
      if (!opcode[0]) src = a; else src = b;
      pval = psel ? 32'(status_q[5:0]) : 32'(p_i);
      pv = unsigned'(pval[5:0]);
      if (opcode[2] == 1'b0) begin  // shifts 0x60..0x63
        if (pval[5] == 1'b0) begin  // upshift 0..31
          shamt = pv;
          y_d = shamt == 0 ? src : (src << shamt);
        end else begin  // downshift 1..32
          shamt = 64 - pv;  // pv in 32..63 -> |p| = 1..32
          if (shamt >= 32) begin
            y_d = (!opcode[1] && src[31]) ? 32'hFFFFFFFF : 32'h0;
          end else if (!opcode[1]) begin  // SN (0x60/61): sign fill
            y_d = (src >> shamt) | (src[31] ? (32'hFFFFFFFF << (32 - shamt))
                                            : 32'h0);
          end else begin  // 0F (0x62/63): zero fill
            y_d = src >> shamt;
          end
        end
      end else begin  // NBROT 0x64/0x65: 5-bit unsigned rotate left
        shamt = unsigned'(pval[4:0]);
        y_d = shamt == 0 ? src : (src << shamt) | (src >> (32 - shamt));
      end
      u_n = 1'b1; f_n = y_d[31];
      u_z = 1'b1; f_z = (y_d == 32'h0);
    end
    // ---------------- bit manipulation ----------------
    7'h66, 7'h67, 7'h68, 7'h69, 7'h6A, 7'h6B, 7'h6C, 7'h6D, 7'h7E: begin
      pval = psel ? 32'(status_q[5:0]) : 32'(p_i);
      pu = pval[4:0];
      psgn_b = pval[5];
      if (opcode == 7'h66 || opcode == 7'h67 || opcode == 7'h7E) begin  // EXTBIT
        src = (opcode == 7'h67) ? b : a;
        f = 32'h0;
        if (opcode == 7'h7E) begin
          statc = stat_comb(status_q, borow_i);
          f[0] = statc[pu] ^ psgn_b;
        end else begin
          f[0] = src[pu] ^ psgn_b;
        end
        y_d = f;
        u_l = 1'b1; f_l = f[0];
        u_z = 1'b1; f_z = (y_d == 32'h0);
      end else if (opcode == 7'h6C || opcode == 7'h6D) begin  // SETBIT/RSTBIT-STAT
        statbit_wen = 1'b1;
        statbit_idx = pu;
        statbit_val = (opcode == 7'h6C);
        y_d = stat_comb(status_q, borow_i);
        if (pu == 5'd13 || pu == 5'd14 || pu == 5'd15 || pu == 5'd23) begin
          statbit_wen = 1'b0;
        end else begin
          y_d[pu] = statbit_val;
        end
      end else begin  // SETBIT-A/B (68/69) / RSTBIT-A/B (6A/6B)
        src = opcode[0] ? b : a;
        if (opcode[1]) begin  // RSTBIT
          y_d = src & ~(32'(1'b1) << pu);
          u_z = 1'b1; f_z = 1'b1;
        end else begin  // SETBIT
          y_d = src | (32'(1'b1) << pu);
          u_z = 1'b1; f_z = 1'b0;
        end
        u_n = 1'b1; f_n = y_d[31];
      end
    end
    // ---------------- field logical / mask ----------------
    7'h6E, 7'h6F, 7'h70, 7'h71, 7'h72, 7'h73, 7'h74, 7'h75,
    7'h76, 7'h77, 7'h78, 7'h79, 7'h7A, 7'h7B, 7'h7C, 7'h7D,
    7'h7F: begin
      pval = psel ? 32'(status_q[5:0]) : 32'(p_i);
      w5v = wsel ? {3'b0, status_q[12:8]} : {1'b0, w_i};
      pv = unsigned'(pval[5:0]);
      pu = pval[4:0];
      psgn_b = pval[5];
      if (opcode == 7'h7F) begin  // PASS-MASK
        m = fmask(32'(pu), 32'(w5v));
        y_d = m ^ (psgn_b ? 32'hFFFFFFFF : 32'h0);
      end else if (opcode == 7'h7A || opcode == 7'h7B) begin  // EXTF-A/B
        src = (opcode == 7'h7A) ? a : b;
        if (!psgn_b) begin
          m = fmask(32'(pv), 32'(w5v));
          y_d = (src << pv) & m;
        end else begin
          shamt = 64 - pv;  // |p| in 1..32
          if (shamt == 32) begin
            y_d = src & fmask(32'h0, 32'(w5v));
          end else begin
            y_d = rotr32(src, shamt) & fmask(32'h0, 32'(w5v));
          end
        end
        u_n = 1'b1; f_n = y_d[31];
        u_z = 1'b1; f_z = (y_d == 32'h0);
      end else if (opcode == 7'h7C || opcode == 7'h7D) begin  // EXTF-AB / EXTF-BA
        // rotate the 64-bit concatenation via a doubled register: the
        // single shift amount 64-pv (33..64 for pv 0..63) keeps every
        // select in range (yosys aig rejects out-of-range x padding)
        logic [63:0] cat, r64;
        logic [127:0] catx;
        src = (opcode == 7'h7C) ? a : b;  // high word
        cat = {src, (opcode == 7'h7C) ? b : a};
        catx = {cat, cat};
        r64 = 64'(catx >> (64 - pv));
        m = fmask(32'h0, 32'(w5v)) & 32'hFFFFFFFF;
        y_d = 32'(r64) & m;
        u_n = 1'b1; f_n = y_d[31];
        u_z = 1'b1; f_z = (y_d == 32'h0);
      end else begin
        if (opcode == 7'h6E || opcode == 7'h6F || opcode == 7'h71 ||
            opcode == 7'h73 || opcode == 7'h75 || opcode == 7'h77 ||
            opcode == 7'h79) begin
          m = fmask(32'(pu), 32'(w5v));
          case (opcode)
            7'h6E:   f = ~b & m;
            7'h6F:   f = b & m;
            7'h71:   f = ~a & m;
            7'h73:   f = a & m;
            7'h75:   f = (a | b) & m;
            7'h77:   f = (a ^ b) & m;
            default: f = (a & b) & m;  // 7'h79
          endcase
          y_d = (b & ~m) | f;
          u_z = 1'b1; f_z = (f == 32'h0);
        end else begin  // non-aligned 70/72/74/76/78
          if (!psgn_b) begin
            m = fmask(32'(pv), 32'(w5v));
            src2 = a << pv;
          end else begin
            m = fmask(32'h0, 32'(w5v));
            shamt = 64 - pv;
            src2 = (shamt == 32) ? a : rotr32(a, shamt);
          end
          case (opcode)
            7'h70:   f = ~src2 & m;
            7'h72:   f = src2 & m;
            7'h74:   f = (src2 | b) & m;
            7'h76:   f = (src2 ^ b) & m;
            default: f = (src2 & b) & m;  // 7'h78
          endcase
          y_d = (b & ~m) | f;
          u_z = 1'b1; f_z = (f == 32'h0);
        end
        u_n = 1'b1; f_n = y_d[31];
      end
    end
    default: y_d = b;  // unspecified opcodes 1E/1F/4C/4D (spec ledger)
    endcase

    y_res = y_d;
  end

  // ------------------------------------------------------------------
  // Status next state
  // ------------------------------------------------------------------
  always_comb begin
    stat_next = status_q;
    if (stat_wmask != 32'h0) begin
      stat_next = (status_q & ~stat_wmask) | (stat_wdat & stat_wmask);
    end
    if (prior_wen) begin
      stat_next[7:0] = {3'b000, prior_val};
    end
    if (statbit_wen) begin
      stat_next[statbit_idx] = statbit_val;
    end
    // flag byte: updated flags take the new value, others keep the
    // (possibly LDSTAT/statbit-written) value
    if (u_c) stat_next[16] = f_c;
    if (u_n) stat_next[17] = f_n;
    if (u_v) stat_next[18] = f_v;
    if (u_z) stat_next[19] = f_z;
    if (u_l) stat_next[20] = f_l;
    if (u_m) stat_next[21] = f_m;
    if (u_s) stat_next[22] = f_s;
    // nibble carries
    if (nc_wen) stat_next[31:24] = nc_d;
    // read-only relational bits: combinational from the final flag byte
    stat_next[15:13] = {(stat_next[17] ^ stat_next[18]) | stat_next[19],
                        stat_next[17] ^ stat_next[18],
                        (borow_i ? !stat_next[16] : stat_next[16])
                        | stat_next[19]};
    stat_next[23] = 1'b0;
  end

  // ------------------------------------------------------------------
  // Outputs
  // ------------------------------------------------------------------
  assign y_o = slave_i ? y_ext_i : y_res;
  assign y_oe_o = !oey_n_i && !slave_i;

  always_comb begin
    py_res = 4'h0;
    for (int i = 0; i < 4; i++) py_res[i] = ^y_res[8*i +: 8];
  end
  // in slave mode the Y/PY pads are inputs: the driven wire value appears
  assign py_o = slave_i ? py_ext_i : py_res;

  always_comb begin
    perr_res = 1'b0;
    for (int i = 0; i < 4; i++) begin
      if ((^da_i[8*i +: 8]) ^ pa_i[i]) perr_res = 1'b1;
      if ((^db_i[8*i +: 8]) ^ pb_i[i]) perr_res = 1'b1;
    end
  end
  // PERR is an input in slave mode
  assign perr_o = slave_i ? perr_ext_i : perr_res;

  always_comb begin
    if (rs_i || hold_i) begin
      flag_pins = {status_q[16], status_q[19], status_q[17],
                   status_q[18], status_q[20]};
    end else begin
      flag_pins = {u_c ? f_c : status_q[16],
                   u_z ? f_z : status_q[19],
                   u_n ? f_n : status_q[17],
                   u_v ? f_v : status_q[18],
                   u_l ? f_l : status_q[20]};
    end
  end
  // C/Z/N/V/L are inputs in slave mode
  assign cznvl_o = slave_i ? cznvl_ext_i : flag_pins;
/* verilator lint_on WIDTH */
/* verilator lint_on UNUSEDSIGNAL */
/* verilator lint_on MULTIDRIVEN */

  // master/slave diagnostic comparators (slave mode compares the externally
  // driven pins against the internal results; in master mode the outputs are
  // our own drive, so there is nothing to compare against)
  always_comb begin
    cmp_y_act = !oey_n_i;
    mserr_o = 1'b0;
    if (slave_i) begin
      if (cmp_y_act && (y_ext_i != y_res)) mserr_o = 1'b1;
      if (cmp_y_act && (py_ext_i != py_res)) mserr_o = 1'b1;
      if (cznvl_ext_i != flag_pins) mserr_o = 1'b1;
      if (perr_ext_i != perr_res) mserr_o = 1'b1;
    end
  end

  // ------------------------------------------------------------------
  // Sequential
  // ------------------------------------------------------------------
  always_ff @(posedge cp_i) begin
    if (!hold_i) begin
      status_q <= stat_next;
      q_q <= q_d;
    end
  end

  // power-up state (no reset pin on the part; spec ledger)
  initial begin
    status_q = 32'h0;
    q_q = 32'h0;
  end

`ifdef FORMAL
  `include "amd_am29332_props.sv"
`endif
endmodule
