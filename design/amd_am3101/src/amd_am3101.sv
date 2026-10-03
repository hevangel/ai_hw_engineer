`timescale 1ns/1ps
// AMD 1974 Data Book pp. 6-11 and 6-15, original Am3101 (not Am3101A).
module amd_am3101 (
    input logic [3:0] a_i,
    input logic cs_n_i,
    input logic we_n_i,
    input logic [3:0] d_i,
    output logic [3:0] q_n_o,
    output logic output_valid_o
);
  logic [3:0] mem [0:15];
  // Actual asynchronous write window; no fabricated clock or reset.
  always_latch begin
    if (!cs_n_i && !we_n_i)
      mem[a_i] = d_i;
  end

  always_comb begin
    output_valid_o = !(cs_n_i && !we_n_i);
    if (cs_n_i && !we_n_i)
      q_n_o = 'x;  // Original truth-table X, not a promised output release.
    else if (!we_n_i)
      q_n_o = ~d_i;
    else if (cs_n_i)
      q_n_o = '1;  // Open collectors released, assuming external pull-ups.
    else
      q_n_o = ~mem[a_i];
  end

`ifdef FORMAL
  always_comb assert (output_valid_o == (!cs_n_i || we_n_i));
`endif
endmodule
