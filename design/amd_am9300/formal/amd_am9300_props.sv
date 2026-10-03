`timescale 1ns/1ps
`ifdef FORMAL
// Pin-level oracle transcribed from AMD Tables I-III, not from the RTL equation.
module amd_am9300_props (
    input logic cp_i, rst_n, pe_n_i, j_i, k_n_i,
    input logic [3:0] p_i
);
  logic [3:0] q;
  logic q3_n;
  logic [3:0] expected;
  logic [2:0] startup = 0;
  logic [3:0] ones_seen = 0;
  logic seen_nonzero_high = 0;

  amd_am9300 dut (
      .cp_i(cp_i), .rst_n(rst_n), .pe_n_i(pe_n_i), .j_i(j_i),
      .k_n_i(k_n_i), .p_i(p_i), .q_o(q), .q3_n_o(q3_n)
  );

  always_ff @(posedge cp_i or negedge rst_n) begin
    if (!rst_n) begin
      expected <= 0;
    end else if (!pe_n_i) begin
      expected <= p_i;
    end else begin
      expected[3] <= expected[2];
      expected[2] <= expected[1];
      expected[1] <= expected[0];
      case ({j_i, k_n_i})
        2'b00: expected[0] <= 0;
        2'b01: expected[0] <= expected[0];
        2'b10: expected[0] <= !expected[0];
        2'b11: expected[0] <= 1;
      endcase
    end
  end

  always_ff @($global_clock) begin
    if (startup < 4) startup <= startup + 1'b1;
    // Hold clear over initial global ticks to initialize both async flops.
    // Every input, including reset and CP, is free after initialization.
    if (startup < 2) assume (!rst_n);
    if (startup >= 3) begin
      assert (q == expected);
      assert (q3_n == !q[3]);
      if (!$past(rst_n)) assert (q == 0);
      cover ($past(rst_n && !pe_n_i && p_i == 4'ha && cp_i) && q == 4'ha);
      if (!rst_n || !pe_n_i || !j_i || !k_n_i)
        ones_seen <= 0;
      else if (cp_i && !$past(cp_i))
        ones_seen <= {ones_seen[2:0], 1'b1};
      cover (ones_seen == 4'hf && q == 4'hf);
      // clk2fflogic observes the result on the current CP transition and
      // uses data sampled before that edge. Require controls stable on both sides.
      cover (rst_n && pe_n_i && !j_i && k_n_i && cp_i && !$past(cp_i)
             && $past(rst_n && pe_n_i && !j_i && k_n_i)
             && q[0] == $past(q[0]) && q[3:1] == $past(q[2:0]));
      cover (rst_n && pe_n_i && j_i && !k_n_i && cp_i && !$past(cp_i)
             && $past(rst_n && pe_n_i && j_i && !k_n_i)
             && q[0] != $past(q[0]) && q[3:1] == $past(q[2:0]));
      seen_nonzero_high <= rst_n && cp_i && q != 0;
      cover (seen_nonzero_high && $past(cp_i) && cp_i && !rst_n && q == 0);
    end
  end
endmodule
`endif
