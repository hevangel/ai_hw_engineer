`timescale 1ns/1ps

// AMD 1974 Data Book, pp. 2-33 and 2-37. Signals denote physical pin levels;
// in particular K and MR are active low. See spec/spec.md for timing scope.
module amd_am9300 (
    input  logic       cp_i,
    input  logic       rst_n,
    input  logic       pe_n_i,
    input  logic       j_i,
    input  logic       k_n_i,
    input  logic [3:0] p_i,
    output logic [3:0] q_o,
    output logic       q3_n_o
);
  logic serial_q0;
  // Characteristic equation of JK with complemented K: 00 clear, 01 hold,
  // 10 toggle, 11 set. Only Q0 holds/toggles; Q1-Q3 always shift in serial mode.
  assign serial_q0 = (j_i & ~q_o[0]) | (k_n_i & q_o[0]);

  always_ff @(posedge cp_i or negedge rst_n) begin
    if (!rst_n)
      q_o <= 4'b0000;
    else if (!pe_n_i)
      q_o <= p_i;
    else
      q_o <= {q_o[2:0], serial_q0};
  end

  assign q3_n_o = ~q_o[3];

`ifdef FORMAL
  always_comb begin
    assert (q3_n_o == ~q_o[3]);
  end
`endif
endmodule
