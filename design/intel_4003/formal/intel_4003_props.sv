`timescale 1ns/1ps

// Formal properties for the Intel 4003 reconstruction (spec sections 4-8).
// All assertions are immediate statements inside a clocked always block
// (Yosys rejects concurrent SVA). The reset assumption itself lives in the
// RTL's `ifdef FORMAL block so the cover task sees it too.
//
// Guards: $past-referencing properties are checked only when reset has been
// released for at least two full cycles (rst_n && !$initstate &&
// $past(rst_n)); current-state properties skip the initial state.
module intel_4003_props #(
    parameter int WIDTH = 10
) (
    input logic             clk,
    input logic             rst_n,
    input logic             cp_i,
    input logic             data_in_i,
    input logic             en_i,
    input logic [WIDTH-1:0] q_o,
    input logic             so_o,
    input logic [WIDTH-1:0] sr,
    input logic             cp_prev,
    input logic             shift_pulse
);

  // ------------------------------------------------------------------
  // Independent reference model (spec section 6.6), written in a
  // different style from the RTL: an explicit conditional inside the
  // clocked block rather than a precomputed next-value.
  // ------------------------------------------------------------------
  logic [WIDTH-1:0] ref_sr;
  logic             ref_cp_prev;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      ref_sr      <= '0;
      ref_cp_prev <= 1'b0;
    end else begin
      ref_cp_prev <= cp_i;
      if (cp_i && !ref_cp_prev) begin
        ref_sr <= {ref_sr[WIDTH-2:0], data_in_i};
      end
    end
  end

  // ------------------------------------------------------------------
  // Assertions
  // ------------------------------------------------------------------
  always @(posedge clk) begin
    // S7: every clock edge that samples a low reset clears the register
    // and CP history at that edge (synchronous reset; the state is
    // therefore zero in every cycle following a reset cycle, including
    // re-asserted resets mid-run).
    if (!$initstate && $past(rst_n) == 1'b0) begin
      a_reset_sr:  assert (sr == '0);
      a_reset_cph: assert (cp_prev == 1'b0);
      a_reset_ref: assert (ref_sr == '0 && ref_cp_prev == 1'b0);
    end

    if (rst_n && !$initstate) begin
      // S1: reference-model equivalence
      a_equiv_sr:  assert (sr == ref_sr);
      a_equiv_cph: assert (cp_prev == ref_cp_prev);
      // S5: enable gates the parallel outputs only
      a_q_on:      assert (!en_i || q_o == sr);
      a_q_off:     assert (en_i || q_o == '0);
      // S6: serial out tracks the last stage regardless of enable
      a_so:        assert (so_o == sr[WIDTH-1]);
    end

    if (rst_n && !$initstate && $past(rst_n)) begin
      // S4: CP history is the previous CP sample
      a_cp_hist: assert (cp_prev == $past(cp_i));
      if ($past(shift_pulse)) begin
        // S2: a shift moves DATA IN into stage 0 and every stage up one
        a_shift_din:   assert (sr[0] == $past(data_in_i));
        a_shift_chain: assert (sr[WIDTH-1:1] == $past(sr[WIDTH-2:0]));
      end else begin
        // S3: no shift event -> register holds (covers one-shift-per-pulse
        // gating: CP held high cannot retrigger, CP low cannot shift)
        a_hold: assert (sr == $past(sr));
      end
    end
  end

endmodule
