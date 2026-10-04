`timescale 1ns/1ps
// Board fixture: four actual native slices, ripple carry and adjacent shift pins.
module tb_top (
    input logic cp_i,
    input logic [8:0] instruction_i,
    input logic [3:0] a_i,b_i,
    input logic [15:0] d_i,
    input logic cn_i,oe_n_i,multiply_i,
    input logic edge_hold_i,q3_hold_i,
    input logic ram0_i,ram3_i,q0_i,q3_i,
    output logic [15:0] y_o,
    output logic cn16_o,ovr_o,zero_o,y_oe_o,
    output logic [8:0] executed_instruction_o,
    output logic multiplier_lsb_o,
    output logic ram0_o,ram3_o,q0_o,q3_o,
    output logic [3:0] ram0_enabled_o,ram3_enabled_o,q0_enabled_o,q3_enabled_o,
    output logic [3:0] p_group_n_o,g_group_n_o,sign_bits_o,overflow_bits_o
);
  logic [4:0] carry;
  logic [3:0] ram_lo,ram_hi,q_lo,q_hi;
  logic [3:0] zero_bits;
  // Manufacturer sign-correction feedback crosses closed RAM read latches
  // during the write phase; it cannot oscillate in a legal CP phase.
  /* verilator lint_off UNOPTFLAT */
  logic [3:0] sign_bits,overflow_bits;
  /* verilator lint_on UNOPTFLAT */
  logic [3:0] ram0_inputs,ram3_inputs,q0_inputs,q3_inputs;
  logic [3:0] y_enabled;
  assign executed_instruction_o=multiply_i ? {instruction_i[8:2],!q_lo[0],instruction_i[0]}:instruction_i;
  assign multiplier_lsb_o=q_lo[0];
  assign ram0_o=ram_lo[0]; assign ram3_o=ram_hi[3];
  assign q0_o=q_lo[0]; assign q3_o=q_hi[3];
  assign sign_bits_o=sign_bits; assign overflow_bits_o=overflow_bits;
  assign carry[0]=cn_i;
  assign cn16_o=carry[4]; assign ovr_o=overflow_bits[3];
  assign zero_o=&zero_bits; assign y_oe_o=&y_enabled;
  assign ram0_inputs={ram_hi[2:0],ram0_i};
  assign q0_inputs={q_hi[2:0],q0_i};
  assign ram3_inputs={multiply_i ? (sign_bits[3]^overflow_bits[3]):ram3_i,ram_lo[3:1]};
  // Test fixture's setup/hold adapter for the externally generated MSB shift
  // input: zero-delay read-latch reopening otherwise races Q's clock edge.
  assign q3_inputs={multiply_i ? (edge_hold_i ? q3_hold_i:ram_lo[0]):q3_i,q_lo[3:1]};
  for (genvar slice=0;slice<4;slice++) begin: slices
    amd_am2901 dut (.cp_i(cp_i),.instruction_i(executed_instruction_o),.a_i(a_i),.b_i(b_i),.d_i(d_i[slice*4+:4]),
        .cn_i(carry[slice]),.oe_n_i(oe_n_i),.ram0_i(ram0_inputs[slice]),.ram3_i(ram3_inputs[slice]),
        .q0_i(q0_inputs[slice]),.q3_i(q3_inputs[slice]),.y_o(y_o[slice*4+:4]),.y_oe_o(y_enabled[slice]),
        .ram0_o(ram_lo[slice]),.ram3_o(ram_hi[slice]),.q0_o(q_lo[slice]),.q3_o(q_hi[slice]),
        .ram0_oe_o(ram0_enabled_o[slice]),.ram3_oe_o(ram3_enabled_o[slice]),
        .q0_oe_o(q0_enabled_o[slice]),.q3_oe_o(q3_enabled_o[slice]),.cn4_o(carry[slice+1]),
        .p_n_o(p_group_n_o[slice]),.g_n_o(g_group_n_o[slice]),
        .ovr_o(overflow_bits[slice]),.f3_o(sign_bits[slice]),.zero_o(zero_bits[slice]));
  end
endmodule
