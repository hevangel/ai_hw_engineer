// Formal properties for the S/360 program status word register.
//
// The checks pin the field-isolation contract that the rest of the core relies
// on: a condition-code write must not disturb the instruction address or the
// instruction length code, an address write must not disturb the code, and a
// whole-word load replaces every bit. Field positions follow A22-6821-7
// Figure 14 (p. 15).
`timescale 1ns/1ps

module ibm_s360_psw_props;

  `include "ibm_s360_defs.svh"

  logic        clk;
  logic        rst_n;
  logic [23:0] reset_ia;
  logic        load;
  logic [63:0] load_data;
  logic        set_ia;
  logic [23:0] ia_in;
  logic        set_ilc;
  logic [1:0]  ilc_in;
  logic        set_cc;
  logic [1:0]  cc_in;
  logic [63:0] psw;
  logic [23:0] ia;
  logic [1:0]  ilc;
  logic [1:0]  cc;

  ibm_s360_psw dut (
      .clk      (clk),
      .rst_n    (rst_n),
      .reset_ia (reset_ia),
      .load     (load),
      .load_data(load_data),
      .set_ia   (set_ia),
      .ia_in    (ia_in),
      .set_ilc  (set_ilc),
      .ilc_in   (ilc_in),
      .set_cc   (set_cc),
      .cc_in    (cc_in),
      .psw      (psw),
      .ia       (ia),
      .ilc      (ilc),
      .cc       (cc)
  );

  // Reset is assumed in the first cycle so the register has a defined initial
  // value and $past() aligns with the clock edge under the formal model.
  always @(posedge clk) begin
    if ($initstate) begin
      assume (!rst_n);
    end
  end

  // Free-running formal clock.
  always_ff @(posedge clk) begin
    if (rst_n) begin
      assert (ia == psw[PSW_IA_MSB:PSW_IA_LSB]);
      assert (ilc == psw[PSW_ILC_MSB -: 2]);
      assert (cc == psw[PSW_CC_MSB -: 2]);
    end
  end

  always_ff @(posedge clk) begin
    // The cycle that leaves reset must clear every field except the address.
    if (rst_n && !$past(rst_n)) begin
      assert (psw[63:24] == 40'd0);
    end
    // Isolation is stated only for cycles whose previous cycle was not a
    // reset cycle, so the reset's dominance cannot be confused with a field
    // update.
    if (rst_n && $past(rst_n)) begin
      if ($past(load)) begin
        assert (psw == $past(load_data));
      end else begin
        if ($past(set_ia)) begin
          assert (ia == $past(ia_in));
        end else begin
          assert (ia == $past(psw[PSW_IA_MSB:PSW_IA_LSB]));
        end
        if ($past(set_ilc)) begin
          assert (ilc == $past(ilc_in));
        end else begin
          assert (ilc == $past(psw[PSW_ILC_MSB -: 2]));
        end
        if ($past(set_cc)) begin
          assert (cc == $past(cc_in));
        end else begin
          assert (cc == $past(psw[PSW_CC_MSB -: 2]));
        end
        // No field strobe touches the key, system mask, ASCII, machine-check,
        // wait, problem-state or interruption-code bits.
        assert (psw[63:32] == $past(psw[63:32]));
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n) begin
      cover (set_ia && set_ilc && set_cc);
      cover (load && (load_data != 64'd0));
      cover (psw[PSW_CC_MSB -: 2] == 2'd3);
    end
  end

endmodule
