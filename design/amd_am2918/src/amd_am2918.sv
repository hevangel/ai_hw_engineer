module amd_am2918 (
  input logic cp_i,
  input logic [3:0] d_i,
  input logic oe_n_i,
  output logic [3:0] q_o, y_o,
  output logic y_oe_o
);
  always_ff @(posedge cp_i) q_o<=d_i;
  // ASSUMPTION: settled digital pins. External wiring resolves Y value/enable;
  // no electrical propagation or contention is modeled.
  assign y_o=q_o;
  assign y_oe_o=!oe_n_i;
`ifdef FORMAL
  `include "amd_am2918_props.sv"
`endif
endmodule
