`timescale 1ns/1ps
module amd_am2901 (
    input logic cp_i,
    input logic [8:0] instruction_i,
    input logic [3:0] a_i, b_i, d_i,
    input logic cn_i, oe_n_i,
    input logic ram0_i, ram3_i, q0_i, q3_i,
    output logic [3:0] y_o,
    output logic y_oe_o,
    output logic ram0_o, ram3_o, q0_o, q3_o,
    output logic ram0_oe_o, ram3_oe_o, q0_oe_o, q3_oe_o,
    // Cascaded carry participates in the same complementary-latch state path.
    /* verilator lint_off UNOPTFLAT */
    output logic cn4_o,
    /* verilator lint_on UNOPTFLAT */
    output logic p_n_o, g_n_o, ovr_o, f3_o, zero_o
);
  logic [3:0] memory [0:15];
  logic [3:0] a_latch, b_latch, q, r, s;
  // The apparent feedback crosses complementary CP-controlled latches.
  // Both cannot be transparent together; phase tests and formal check this.
  // Keep this waiver local to that state path; no combinational ALU waiver.
  /* verilator lint_off UNOPTFLAT */
  logic [3:0] ram_input, f;
  /* verilator lint_on UNOPTFLAT */
  logic [2:0] dest;
`ifdef FORMAL
  // Break the structural transparent-latch loop for the formal netlist.
  // Equality in the property harness preserves the original write equation.
  (* anyseq *) logic [3:0] storage_write_data;
`else
  logic [3:0] storage_write_data;
  assign storage_write_data=ram_input;
`endif
  assign dest=instruction_i[8:6];
  // Manufacturer CP phases: read latches HIGH, RAM write latch LOW, Q rising.
  // ASSUMPTION: external controls satisfy the documented setup/hold times.
  always_latch begin
    if (cp_i) begin a_latch=memory[a_i]; b_latch=memory[b_i]; end
  end
  for (genvar word_index=0;word_index<16;word_index++) begin: ram_words
    always_latch begin
      if (!cp_i && dest>=3'd2 && b_i==4'(word_index)) memory[word_index]=storage_write_data;
    end
  end
  always_ff @(posedge cp_i) begin
    case (dest)
      3'd0: q<=f;
      3'd4: q<={q3_i,q[3:1]};
      3'd6: q<={q[2:0],q0_i};
      default: ;
    endcase
  end
  always_comb begin
    r=0; s=0;
    case (instruction_i[2:0])
      3'd0: begin r=a_latch; s=q; end
      3'd1: begin r=a_latch; s=b_latch; end
      3'd2: s=q;
      3'd3: s=b_latch;
      3'd4: s=a_latch;
      3'd5: begin r=d_i; s=a_latch; end
      3'd6: begin r=d_i; s=q; end
      3'd7: r=d_i;
      default: ;
    endcase
  end
  always_comb begin
    ram_input=f;
    if (dest==3'd4 || dest==3'd5) ram_input={ram3_i,f[3:1]};
    if (dest==3'd6 || dest==3'd7) ram_input={f[2:0],ram0_i};
  end
  assign y_o=dest==3'd2 ? a_latch : f;
  assign y_oe_o=!oe_n_i;
  assign ram0_o=f[0]; assign ram3_o=f[3]; assign q0_o=q[0]; assign q3_o=q[3];
  assign ram0_oe_o=(dest==3'd4 || dest==3'd5);
  assign ram3_oe_o=(dest==3'd6 || dest==3'd7);
  assign q0_oe_o=(dest==3'd4); assign q3_oe_o=(dest==3'd6);
  amd_am2901_alu alu (.r_i(r),.s_i(s),.function_i(instruction_i[5:3]),.cn_i(cn_i),
      .f_o(f),.cn4_o(cn4_o),.p_n_o(p_n_o),.g_n_o(g_n_o),.ovr_o(ovr_o),.f3_o(f3_o),.zero_o(zero_o));
`ifdef FORMAL
  `include "amd_am2901_props.sv"
`endif
endmodule
