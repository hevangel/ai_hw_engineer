`timescale 1ns/1ps
// Five Am2901 slices as a 20-bit datapath with an 18-bit architectural
// boundary. Guard bits [19:18] are written zero on every architectural
// write; a carry out of bit 17 appears as bit 18 of the ALU result and is
// consumed by the microcode's end-around-carry fix-up.
//
// Destination code 3 presents F on the slice Y bus (result visible to glue);
// destination code 2 presents the A-port value on Y and still writes F, which
// is what the shift network and memory-write cycles need.
//
// The architectural shift network is external glue (as the original PDP-1
// used discrete shift gates): the A-port value is presented on Y with
// destination code 2, shifted one place, driven onto the D bus and written
// back through the slices as F = D. See spec.md A4.
`ifndef PDP1_DATAPATH_SV
`define PDP1_DATAPATH_SV

module pdp1_datapath (
    input  logic                   clk_i,
    input  logic                   rst_n_i,
    input  pdp1_uc_pkg::pdp1_uc_t  uc_i,
    input  logic [17:0]            ir_i,
    input  logic [17:0]            mb_i,
    input  logic [17:0]            mem_i,
    input  logic [11:0]            pc_i,
    input  logic [11:0]            ma_i,
    input  logic [17:0]            tw_i,
    input  logic [5:0]             ss_i,
    input  logic [17:0]            status_i,
    input  logic [17:0]            devdata_i,
    output logic [19:0]            y_o,
    output logic [17:0]            shf_o,
    output logic [17:0]            d_o,
    output logic                   alu_zero_o,
    output logic                   ov_next_o,
    output logic [19:0]            ac_o,
    output logic [19:0]            io_o
);

  `include "pdp1_defs.svh"

  logic [3:0]  y_slice[0:4];
  logic [19:0] y_bus;
  logic [19:0] d_bus;
  logic [17:0] d_value, d_eff;
  logic [4:0]  slice_zero;
  logic [4:0]  cn_chain;
  logic [4:0]  cn4_vec;
  logic [1:0]  cn_sel;
  logic [8:0]  alu_i;
  logic [17:0] shf_value, shf_input;
  logic        fill_bit;
  logic        ext_a_q, ext_b_q;
  logic [19:0] ac_q, io_q;
  logic [19:0] writeback;
  logic        ac_we, io_we;

  assign alu_i = {uc_i.dest, uc_i.fn, uc_i.src};

  always_comb begin
    unique case (uc_i.cn)
      2'd1: cn_sel = 2'd1;
      default: cn_sel = 2'd0;
    endcase
  end
  assign cn_chain[0] = cn_sel[0];  // ripple chain, no lookahead

  // The Am2901 chain ripples Cn+4 into the next slice's Cn; Verilator reports
  // the array as a cycle although the path is strictly forward. The slices
  // themselves carry the same documented waiver for their internal latch path.
  /* verilator lint_off UNOPTFLAT */
  genvar gi;
  generate
    for (gi = 0; gi < 5; gi++) begin : slices
      if (gi > 0) begin : chain
        assign cn_chain[gi] = cn4_vec[gi-1];
      end
      amd_am2901 slice (
          .cp_i(clk_i),
          .instruction_i(alu_i),
          .a_i(uc_i.a),
          .b_i(uc_i.b),
          .d_i(d_bus[gi*4 +: 4]),
          .cn_i(cn_chain[gi]),
          .oe_n_i(1'b0),
          .ram0_i(1'b0),
          .ram3_i(1'b0),
          .q0_i(1'b0),
          .q3_i(1'b0),
          .y_o(y_slice[gi]),
          .y_oe_o(),
          .ram0_o(),
          .ram3_o(),
          .q0_o(),
          .q3_o(),
          .ram0_oe_o(),
          .ram3_oe_o(),
          .q0_oe_o(),
          .q3_oe_o(),
          .cn4_o(cn4_vec[gi]),
          .p_n_o(),
          .g_n_o(),
          .ovr_o(),
          .f3_o(),
          .zero_o(slice_zero[gi])
      );
      assign y_bus[gi*4 +: 4] = y_slice[gi];
    end
  endgenerate
  /* verilator lint_on UNOPTFLAT */

  assign y_o = y_bus;
  assign shf_o = shf_value;
  assign d_o = d_eff;
  assign alu_zero_o = &slice_zero;

  // D-bus source mux (18 bits; guard bits are always zero).
  always_comb begin
    unique case (uc_i.d)
      D_ZERO:    d_value = 18'd0;
      D_ONE:     d_value = 18'd1;
      D_ONES:    d_value = 18'h3FFFF;
      D_MB:      d_value = mb_i;
      D_MEM:     d_value = mem_i;
      D_ADDR:    d_value = {6'd0, ir_i[11:0]};
      D_ADDR1:   d_value = {6'd0, ir_i[11:0] + 12'd1};
      D_PC:      d_value = {6'd0, pc_i};
      D_MA:      d_value = {6'd0, ma_i};
      D_TW:      d_value = tw_i;
      D_SS:      d_value = {12'd0, ss_i};
      D_Y:       d_value = y_bus[17:0];
      D_SHF:     d_value = shf_value;
      D_IMM:     d_value = uc_i.imm;
      D_STATUS:  d_value = status_i;
      D_DEVDATA: d_value = devdata_i;
      default:   d_value = 18'd0;
    endcase
  end
  assign d_eff = d_value ^ {18{uc_i.d_inv}};
  assign d_bus = {2'b00, d_eff};

  // 18-bit one-place shift network. Its input is the A-port value, which the
  // slices present on Y exactly when the destination field is 2; gating on the
  // same code is what keeps Y -> shift -> D -> ALU -> Y from being a loop.
  assign shf_input = (uc_i.dest == DEST_RAM_Y_A) ? y_bus[17:0] : 18'd0;

  // FILL_SIGN is the arithmetic fill; shf_sign preserves the accumulator sign
  // for arithmetic left shifts.
  /* verilator lint_off UNOPTFLAT */
  always_comb begin
    unique case (uc_i.shf_fill)
      FILL_ZERO: fill_bit = 1'b0;
      FILL_SIGN: fill_bit = y_bus[17];
      FILL_EXT_A: fill_bit = ext_a_q;
      FILL_EXT_B: fill_bit = ext_b_q;
      FILL_ROT:  fill_bit = (uc_i.shf_dir == SHF_LEFT) ? y_bus[17] : y_bus[0];
      default:   fill_bit = 1'b0;
    endcase
    unique case (uc_i.shf_dir)
      SHF_LEFT: begin
        shf_value = {shf_input[16:0], fill_bit};
        if (uc_i.shf_sign) shf_value[17] = shf_input[17];
      end
      SHF_RIGHT: shf_value = {fill_bit, shf_input[17:1]};
      default:   shf_value = shf_input;
    endcase
  end
  /* verilator lint_on UNOPTFLAT */

  // Edge capture for combined AC/IO shifts. Each phase captures the bit that
  // will leave its own register into a dedicated latch, so both registers'
  // pre-shift edges are available before either shift runs. Sampled on the low
  // phase like the slice RAM write.
  always_ff @(negedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      ext_a_q <= 1'b0;
      ext_b_q <= 1'b0;
    end else if (uc_i.cap_sel == CAP_A) begin
      ext_a_q <= (uc_i.shf_dir == SHF_LEFT) ? y_bus[17] : y_bus[0];
    end else if (uc_i.cap_sel == CAP_B) begin
      ext_b_q <= (uc_i.shf_dir == SHF_LEFT) ? y_bus[17] : y_bus[0];
    end
  end

  // Value written into a slice RAM word this cycle.
  assign writeback = (uc_i.dest == DEST_RAM_Y_A) ? {2'b00, shf_value} : y_bus;
  assign ac_we = ((uc_i.dest == DEST_RAM_Y_A) || (uc_i.dest == DEST_RAM_Y_F)) &&
                 (uc_i.b == REG_AC);
  assign io_we = ((uc_i.dest == DEST_RAM_Y_A) || (uc_i.dest == DEST_RAM_Y_F)) &&
                 (uc_i.b == REG_IO);

  // One's-complement overflow: the A operand is the accumulator for every
  // micro-op that reports overflow, so its sign comes from the mirror.
  // (The slice OVR pin observes bit 19 and is unusable here, ASSUMPTION A3.)
  assign ov_next_o = (ac_q[17] ^ y_bus[17]) & (d_eff[17] ^ ac_q[17]);

  // Architectural mirrors: exact because every AC/IO write passes through a
  // known writeback path (shf_value for destination 2, Y = F otherwise).
  // They update on the low phase with the slice RAM write; sampling at the
  // rising edge would race the transparent address latches.
  always_ff @(negedge clk_i or negedge rst_n_i) begin
    if (!rst_n_i) begin
      ac_q <= 20'd0;
      io_q <= 20'd0;
    end else begin
      if (ac_we) ac_q <= writeback;
      if (io_we) io_q <= writeback;
    end
  end
  assign ac_o = ac_q;
  assign io_o = io_q;

endmodule

`endif
