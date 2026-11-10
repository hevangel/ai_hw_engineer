// Formal properties for the S/360 program status word register (M2).
//
// The checks pin the field-isolation contract that the rest of the core relies
// on: a condition-code write must not disturb the instruction address, the
// ILC, the program mask or the system mask; a program-mask or system-mask write
// must not disturb the others; and a whole-word load replaces every bit except
// the interruption code and ILC, which A22-6821-7 p. 73 says are not retained.
// Field positions follow Figure 14 (p. 15).
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
  logic        set_pmask;
  logic [3:0]  pmask_in;
  logic        set_sysmask;
  logic [7:0]  sysmask_in;
  logic [63:0] psw;
  logic [23:0] ia;
  logic [1:0]  ilc;
  logic [1:0]  cc;
  logic [3:0]  pmask;
  logic        problem;
  logic        wait_state;

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
      .set_pmask(set_pmask),
      .pmask_in (pmask_in),
      .set_sysmask(set_sysmask),
      .sysmask_in(sysmask_in),
      .psw      (psw),
      .ia       (ia),
      .ilc      (ilc),
      .cc       (cc),
      .pmask    (pmask),
      .problem  (problem),
      .wait_state(wait_state)
  );

  // Reset is assumed in the first cycle so the register has a defined initial
  // value and $past() aligns with the clock edge under the formal model.
  always @(posedge clk) begin
    if ($initstate) begin
      assume (!rst_n);
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n) begin
      assert (ia == psw[PSW_IA_MSB:PSW_IA_LSB]);
      assert (ilc == psw[PSW_ILC_MSB -: 2]);
      assert (cc == psw[PSW_CC_MSB -: 2]);
      assert (pmask == psw[PSW_PMASK_MSB -: 4]);
      assert (problem == psw[PSW_PROBLEM_BIT]);
      assert (wait_state == psw[PSW_WAIT_BIT]);
    end
  end

  always_ff @(posedge clk) begin
    // The cycle that leaves reset must clear every field except the address.
    if (rst_n && !$past(rst_n)) begin
      assert (psw[63:24] == 40'd0);
    end
    if (rst_n && $past(rst_n)) begin
      if ($past(load)) begin
        // Interruption code and ILC are not retained across a load.
        assert (psw[PSW_SYSMASK_MSB -: 16] == $past(load_data[PSW_SYSMASK_MSB -: 16]));
        assert (psw[PSW_INTCODE_MSB -: 16] == 16'd0);
        assert (psw[PSW_ILC_MSB -: 2] == 2'd0);
        assert (psw[PSW_CC_MSB -: 6] == $past(load_data[PSW_CC_MSB -: 6]));
        assert (psw[PSW_IA_MSB:PSW_IA_LSB] == $past(load_data[PSW_IA_MSB:PSW_IA_LSB]));
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
        if ($past(set_pmask)) begin
          assert (pmask == $past(pmask_in));
        end else begin
          assert (pmask == $past(psw[PSW_PMASK_MSB -: 4]));
        end
        if ($past(set_sysmask)) begin
          assert (psw[PSW_SYSMASK_MSB -: 8] == $past(sysmask_in));
        end else begin
          assert (psw[PSW_SYSMASK_MSB -: 8] == $past(psw[PSW_SYSMASK_MSB -: 8]));
        end
        // No field strobe touches the key, ASCII, machine-check, wait or
        // problem-state bits (the system mask has its own strobe above).
        assert (psw[55:48] == $past(psw[55:48]));
        assert (psw[PSW_INTCODE_MSB -: 16] == $past(psw[PSW_INTCODE_MSB -: 16]));
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst_n) begin
      cover (set_ia && set_ilc && set_cc && set_pmask && set_sysmask);
      cover (load && (load_data != 64'd0));
      cover (pmask == 4'hF);
      cover (problem && wait_state);
      cover (psw[PSW_CC_MSB -: 2] == 2'd3);
    end
  end

endmodule
