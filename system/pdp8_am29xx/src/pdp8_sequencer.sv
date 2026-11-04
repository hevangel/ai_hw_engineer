// Microprogram sequencer adapter around the Am2910 model.
//
// The Am2910 drives a control-store address bus.  This wrapper mirrors the
// sequencer's micro-program counter in `mpc_o` so the control store can be a
// combinational ROM with no combinational path back into the sequencer.
//
// CI convention.  The Am29xx model loads micro-PC <= Y + CI at each clock
// edge.  A sequential step therefore needs CI = 1 while a taken conditional
// branch (Y = D) needs CI = 0.  CRTN (return) must resume *after* the call
// site, which is the pushed micro-PC, so returns also use CI = 1.
//
// ASSUMPTION: the model's D input is the exact branch target.  The board-level
// CI wiring is the caller's responsibility in the Am2910 specification; this
// adapter supplies the increment that a real sequencer board would generate.
module pdp8_sequencer (
    input  logic        clk_i,
    input  logic        boot_i,     // hold at address zero with JZ while high
    input  logic [3:0]  seq_i,
    input  logic [11:0] target_i,
    input  logic        cc_n_i,
    output logic [11:0] mpc_o,
    output logic        full_n_o
);
  localparam logic [3:0] SEQ_JZ  = 4'h0;
  localparam logic [3:0] SEQ_CJS = 4'h1;
  localparam logic [3:0] SEQ_CJP = 4'h3;
  localparam logic [3:0] SEQ_RTN = 4'ha;

  logic [11:0] y;
  logic        ci;

  // Taken CJP/CJS present the branch address and must not be incremented.
  assign ci = !(((seq_i == SEQ_CJP) || (seq_i == SEQ_CJS)) && !cc_n_i);

  amd_am2910 u_seq (
      .cp_i         (clk_i),
      .instruction_i(boot_i ? SEQ_JZ : seq_i),
      .d_i          (boot_i ? 12'd0 : target_i),
      .cc_n_i       (boot_i ? 1'b1 : cc_n_i),
      .ccen_n_i     (1'b0),
      .ci_i         (boot_i ? 1'b0 : ci),
      .rld_n_i      (1'b1),
      .oe_n_i       (1'b0),
      .y_o          (y),
      .y_oe_o       (),
      .full_n_o     (full_n_o),
      .pl_n_o       (),
      .map_n_o      (),
      .vect_n_o     ()
  );

  always_ff @(posedge clk_i) begin
    if (boot_i) mpc_o <= 12'd0;
    else mpc_o <= y + 12'(ci);
  end

`ifdef FORMAL
  // The mirror must stay identical to the sequencer's own counter.
  logic f_past_valid = 1'b0;
  always_ff @(posedge clk_i) f_past_valid <= 1'b1;
  always_ff @(posedge clk_i) begin
    if (f_past_valid && $past(!boot_i) && !$past(boot_i))
      assert (mpc_o == y);
  end
`endif
endmodule
