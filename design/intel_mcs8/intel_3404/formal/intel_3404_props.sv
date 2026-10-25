`timescale 1ns/1ps
`ifdef FORMAL
module intel_3404_props (
    input logic clk,
    input logic rst_n,
    input logic [5:0] d_i,
    input logic w4_n_i,
    input logic w2_n_i
);
  logic [5:0] q_n;
  intel_3404 dut (.clk(clk), .rst_n(rst_n), .d_i(d_i), .w4_n_i(w4_n_i), .w2_n_i(w2_n_i), .q_n_o(q_n));

  // Reset is assumed active for the first cycle so the stored state is
  // deterministic from cycle 1 on (repo convention: assume reset initially).
  initial begin
    assume(!rst_n);
  end

  // $past registers start unconstrained in the formal initial state, and
  // the stored bits are unconstrained before the first reset edge: gate
  // every $past-based property on this flag so nothing is checked against
  // pre-history values.
  logic f_past_valid = 1'b0;
  always_ff @(posedge clk) begin
    f_past_valid <= 1'b1;
  end

  always_ff @(posedge clk) begin
    if (f_past_valid) begin
      if ($past(rst_n)) begin
        // Write semantics: a section whose write enable was low at the
        // previous edge follows the inverted data; a section whose enable
        // was high holds its stored value (formulated from the datasheet
        // timing diagram, independent of the RTL enable structure).
        if (!$past(w4_n_i)) begin
          assert(q_n[3:0] == $past(~d_i[3:0]));
        end else begin
          assert(q_n[3:0] == $past(q_n[3:0]));
        end
        if (!$past(w2_n_i)) begin
          assert(q_n[5:4] == $past(~d_i[5:4]));
        end else begin
          assert(q_n[5:4] == $past(q_n[5:4]));
        end
      end else begin
        // Reset landed at the previous edge: stored bits are zero, so the
        // inverted outputs sit high.
        assert(q_n == 6'b11_1111);
      end

      // Section independence, stated separately from the write/hold cases
      // above: a write to one section never disturbs the other.
      if ($past(rst_n) && $past(w4_n_i)) begin
        assert(q_n[3:0] == $past(q_n[3:0]));
      end
      if ($past(rst_n) && $past(w2_n_i)) begin
        assert(q_n[5:4] == $past(q_n[5:4]));
      end

      // Non-vacuity: every operating mode is reachable.
      cover($past(rst_n) && !$past(w4_n_i) && $past(w2_n_i));  // 4-bit write, 2-bit hold
      cover($past(rst_n) && $past(w4_n_i) && !$past(w2_n_i));  // 2-bit write, 4-bit hold
      cover($past(rst_n) && !$past(w4_n_i) && !$past(w2_n_i)); // simultaneous write
      cover($past(rst_n) && $past(w4_n_i) && $past(w2_n_i));   // both hold
      cover($past(rst_n) && !$past(w4_n_i) && !$past(w2_n_i)
            && $past(d_i[3:0]) == 4'h0 && $past(d_i[5:4]) == 2'b11);
      cover(!rst_n);                                           // reset cycle reachable
    end
  end
endmodule
`endif
