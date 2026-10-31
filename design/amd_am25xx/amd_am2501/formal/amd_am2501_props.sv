`timescale 1ns/1ps
`ifdef FORMAL
module amd_am2501_props #(
    parameter int CE_INPUTS = 6
) (
    input logic cp_i, cd_n_i, pe_n_i,
    input logic [CE_INPUTS-1:0] ce_i,
    input logic [3:0] p_i
);
  logic [3:0] q;
  logic tc;
  logic [3:0] expected;
  logic valid = 0;
  // Each nibble indexes Figure 7's successor/predecessor, least state first.
  localparam logic [63:0] UP_STATES   = 64'h0fedcba987654321;
  localparam logic [63:0] DOWN_STATES = 64'hedcba9876543210f;

  amd_am2501 #(.CE_INPUTS(CE_INPUTS)) dut (
      .cp_i(cp_i), .cd_n_i(cd_n_i), .pe_n_i(pe_n_i), .ce_i(ce_i),
      .p_i(p_i), .q_o(q), .tc_o(tc)
  );
  always_ff @(posedge cp_i) begin
    if (!valid) assume (!pe_n_i);
    valid <= 1;
    if (!pe_n_i)
      expected <= p_i;
    else if (&ce_i)
      expected <= cd_n_i ? UP_STATES[4*expected +: 4] : DOWN_STATES[4*expected +: 4];

    if (valid) begin
      assert (q == expected);
      assert (tc == (cd_n_i ? (expected == 15) : (expected == 0)));
      cover ($past(pe_n_i && (&ce_i) && cd_n_i && q == 15) && q == 0);
      cover ($past(pe_n_i && (&ce_i) && !cd_n_i && q == 0) && q == 15);
      cover (pe_n_i && !( &ce_i) && tc && q == $past(q));
      cover ($past(!pe_n_i && !( &ce_i) && p_i == 4'ha) && q == 4'ha);
    end
  end
endmodule
`endif
