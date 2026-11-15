// AMD Am29323 32x32 parallel multiplier with 67-bit accumulator,
// edge-accurate digital model.
//
// Sources:
//   AMD 1985 Am29300 Family Handbook, "Am29323 32-Bit Parallel
//   Multiplier" advanced information (PDF 46-52): pin descriptions,
//   Tables 1-3, X/Y input and P output data-format figures (page images
//   inspected). Primary contract for the bipolar member.
//   AMD 1988 Am29C300/29300 Data Book, "Am29C323 CMOS 32-Bit Parallel
//   Multiplier" preliminary (PDF 266-289): supplies the SHIFT AND
//   ACCUMULATE definition (product register shifted 32 bits right, sign
//   extended, accumulated with the array output) and the 67-bit layout
//   (lower 64 bits output, upper 3 bits overflow). The CMOS member
//   documents the same function and shares this RTL (member #176).
//
// All registers clock on CLK rising edges; enables are active low;
// feedthrough controls (FTX/FTY/FTI/FTP) are active high and bypass the
// corresponding register combinationally. Electrical timing is outside
// the contract. Undefined or under-specified behavior is resolved in the
// spec assumption ledger: ACC=10 is INVALID and holds the accumulator;
// RND adds the bit just below the selected most-significant-word slice
// to that slice (rounded add wraps, overflow of the round add dropped);
// FTP bypasses the accumulator register into the output multiplexer and
// temporary-register capture path; the I register holds the seven
// command bits; PARERR masters drive their own input-parity error;
// HARDERR reports driven-vs-observed output mismatch in both modes.
module amd_am29323 (
  input  logic        clk_i,
  input  logic [31:0] x_i, y_i,
  input  logic [3:0]  px_i, py_i,       // even-parity inputs, X and Y bytes
  input  logic [31:0] p_i,              // P port observed value
  output logic [31:0] p_o,              // P port computed value
  output logic        p_oe_o,
  input  logic [3:0]  pp_i,
  output logic [3:0]  pp_o,
  output logic        pp_oe_o,
  input  logic        parerr_i,
  output logic        parerr_o,
  output logic        parerr_oe_o,
  output logic        harderr_o,
  input  logic        tcx_i, tcy_i,     // 1 = two's complement, 0 = unsigned
  input  logic        acc0_i, acc1_i,   // accumulator command (via I register)
  input  logic        rnd_i,            // round MS product word (via I)
  input  logic        tsel_i, fa_i,     // T select and format adjust (via I)
  input  logic        psel0_i, psel1_i, // P mux select (via I)
  input  logic        enxa_n_i, enxb_n_i,
  input  logic        enya_n_i, enyb_n_i,
  input  logic        enp_n_i, eni_n_i, ent_n_i,
  input  logic        ftx_i, fty_i, fti_i, ftp_i,
  input  logic        xsel_i, ysel_i,   // 1 = A register, 0 = B register
  input  logic        oe_n_i,
  input  logic        slave_i
`ifdef FORMAL
  , input logic fml_clk_i               // formal-only property timebase
`endif
);

  // Registered state.
  logic [31:0] xa_q, xb_q, ya_q, yb_q, t_q;
  logic [66:0] acc_q;                   // lower 64 output bits + 3 overflow
  logic [6:0]  i_q;                     // {ACC1,ACC0,RND,TSEL,FA,PSEL1,PSEL0}

  // Effective command word: FTI bypasses the instruction register.
  wire [6:0] cmd = fti_i ? {acc1_i, acc0_i, rnd_i, tsel_i, fa_i,
                            psel1_i, psel0_i} : i_q;
  wire acc1  = cmd[6];
  wire acc0  = cmd[5];
  wire rnd   = cmd[4];
  wire tsel  = cmd[3];
  wire fa    = cmd[2];
  wire psel1 = cmd[1];
  wire psel0 = cmd[0];

  // Multiplier array operands: feedthrough or selected register.
  wire [31:0] xm = ftx_i ? x_i : (xsel_i ? xa_q : xb_q);
  wire [31:0] ym = fty_i ? y_i : (ysel_i ? ya_q : yb_q);

  // Product. Mixed modes: each operand is treated per its TC pin; the
  // result is two's complement when either input is TC (datasheet
  // operational modes). Explicit 64-bit sign/zero extension keeps the
  // multiply exact under SystemVerilog unsigned-expression rules.
  wire signed [63:0] xa_ext = tcx_i ? signed'({{32{xm[31]}}, xm})
                                    : signed'({32'b0, xm});
  wire signed [63:0] ya_ext = tcy_i ? signed'({{32{ym[31]}}, ym})
                                    : signed'({32'b0, ym});
  wire signed [63:0] prod = xa_ext * ya_ext;
  wire [66:0] prod67 = {{3{prod[63]}}, prod};

  // Accumulator next value (Table 1). ACC=10 is INVALID (hold).
  wire [66:0] acc_shifted = {{32{acc_q[66]}}, acc_q[66:32]};  // >> 32, sign ext
  logic [66:0] acc_n;
  always_comb begin
    case ({acc1, acc0})
      2'b00: acc_n = prod67;                       // PASS
      2'b01: acc_n = acc_q + prod67;               // ACCUMULATE
      2'b10: acc_n = acc_q;                        // INVALID: hold (ledger)
      2'b11: acc_n = acc_shifted + prod67;         // SHIFT AND ACCUMULATE
      default: acc_n = acc_q;
    endcase
  end

  // Slice source: the accumulator register, or the raw array product
  // with FTP (feedthrough bypass of the product register, ledger). The
  // upper overflow bits [66:64] are visible only through the arithmetic
  // (SHIFT AND ACCUMULATE sign extension), not sliced directly.
  wire [66:0] psrc = ftp_i ? prod67 : acc_q;
  wire _unused_psrc_hi = &{1'b0, psrc[66:64], 1'b0};

  // Word slices per the data-format figure (FA) and Table 2/3 indices.
  wire [31:0] w_lo_fa1 = psrc[31:0];               // Pi
  wire [31:0] w_lo_fa0 = {psrc[30:0], 1'b0};       // Pi-1 (LSB becomes zero)
  wire [31:0] w_hi_fa1 = psrc[63:32];              // Pi+32
  wire [31:0] w_hi_fa0 = psrc[62:31];              // Pi+31
  // RND rounds the most significant word: add the bit just below the
  // slice (the half-LSB of the discarded half), overflow dropped.
  wire [31:0] w_hi_fa1_r = w_hi_fa1 + (rnd ? {31'b0, psrc[31]} : 32'b0);
  wire [31:0] w_hi_fa0_r = w_hi_fa0 + (rnd ? {31'b0, psrc[30]} : 32'b0);

  // Temporary register input (Table 2).
  wire [31:0] t_in = tsel ? (fa ? w_hi_fa1_r : w_hi_fa0_r)
                          : (fa ? w_lo_fa1  : w_lo_fa0);

  // P port multiplexer (Table 3).
  wire disable_p = psel1 && psel0;
  logic [31:0] p_mux;
  always_comb begin
    case ({psel1, psel0})
      2'b00: p_mux = t_q;                                              // TEMP
      2'b01: p_mux = fa ? w_lo_fa1  : w_lo_fa0;                        // Pi-1/Pi
      2'b10: p_mux = fa ? w_hi_fa1_r : w_hi_fa0_r;                     // Pi+31/32
      default: p_mux = '0;                                             // DISABLE
    endcase
  end

  assign p_oe_o  = !oe_n_i && !disable_p && !slave_i;
  assign pp_oe_o = p_oe_o;
  assign p_o     = p_mux;
  // Even parity per byte of the multiplexer value (input side of the
  // output translator, per the datasheet).
  assign pp_o    = {^p_mux[31:24], ^p_mux[23:16], ^p_mux[15:8], ^p_mux[7:0]};

  // Input parity checking: even parity expected on each X/Y byte.
  wire [3:0] xpar = {^x_i[31:24], ^x_i[23:16], ^x_i[15:8], ^x_i[7:0]};
  wire [3:0] ypar = {^y_i[31:24], ^y_i[23:16], ^y_i[15:8], ^y_i[7:0]};
  wire perr = ((px_i ^ xpar) != 4'b0) || ((py_i ^ ypar) != 4'b0);
  assign parerr_oe_o = !slave_i;
  assign parerr_o    = perr;

  // HARDERR: driven-vs-observed mismatch on the bidirectional outputs
  // in both modes (master contention, slave comparison).
  wire cmp_err = (p_oe_o    && (p_o     != p_i)) ||
                 (pp_oe_o   && (pp_o    != pp_i)) ||
                 (parerr_oe_o && (parerr_o != parerr_i));
  assign harderr_o = cmp_err;

  // Sequential behavior.
  always_ff @(posedge clk_i) begin
    if (!enxa_n_i) xa_q <= x_i;
    if (!enxb_n_i) xb_q <= x_i;
    if (!enya_n_i) ya_q <= y_i;
    if (!enyb_n_i) yb_q <= y_i;
    if (!enp_n_i)  acc_q <= acc_n;
    if (!ent_n_i)  t_q  <= t_in;
    if (!eni_n_i)  i_q  <= {acc1_i, acc0_i, rnd_i, tsel_i, fa_i,
                            psel1_i, psel0_i};
  end

`ifdef FORMAL
  `include "amd_am29323_props.sv"
`endif
endmodule
