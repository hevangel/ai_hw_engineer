module amd_am2913 (
  input logic [7:0] request_n_i,
  input logic ei_n_i,
  input logic g1_i, g2_i, g3_n_i, g4_n_i, g5_n_i,
  output logic [2:0] a_o,
  output logic a_oe_o, eo_n_o
);
  logic found;
  // ASSUMPTION: settled digital values; external logic resolves a_o/a_oe_o.
  always_comb begin
    a_o=0;
    found=0;
    for(integer b=7;b>=0;b=b-1) begin
      if(!ei_n_i && !request_n_i[b] && !found) begin
        a_o=3'(b);
        found=1;
      end
    end
    eo_n_o=ei_n_i || !( &request_n_i );
    a_oe_o=g1_i && g2_i && !g3_n_i && !g4_n_i && !g5_n_i;
  end
`ifdef FORMAL
  `include "amd_am2913_props.sv"
`endif
endmodule
