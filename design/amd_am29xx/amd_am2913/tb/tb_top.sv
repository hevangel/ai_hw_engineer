module tb_top (
  input logic [7:0] request_n_i,
  input logic ei_n_i,
  input logic [4:0] gates_i,
  output logic [2:0] a_o,
  output logic a_oe_o, eo_n_o,
  input logic [15:0] cascade_request_n_i,
  output logic [2:0] cascade_high_a_o, cascade_low_a_o,
  output logic cascade_high_eo_n_o, cascade_low_eo_n_o,
  output logic cascade_high_oe_o, cascade_low_oe_o,
  input logic [63:0] hierarchy_request_n_i,
  output logic [5:0] hierarchy_a_o,
  output logic hierarchy_eo_n_o
);
  amd_am2913 dut(.request_n_i(request_n_i),.ei_n_i(ei_n_i),
    .g1_i(gates_i[0]),.g2_i(gates_i[1]),.g3_n_i(gates_i[2]),
    .g4_n_i(gates_i[3]),.g5_n_i(gates_i[4]),.a_o(a_o),.a_oe_o(a_oe_o),.eo_n_o(eo_n_o));
  amd_am2913 high_chip(.request_n_i(cascade_request_n_i[15:8]),.ei_n_i(ei_n_i),
    .g1_i(gates_i[0]),.g2_i(gates_i[1]),.g3_n_i(gates_i[2]),
    .g4_n_i(gates_i[3]),.g5_n_i(gates_i[4]),.a_o(cascade_high_a_o),
    .a_oe_o(cascade_high_oe_o),.eo_n_o(cascade_high_eo_n_o));
  amd_am2913 low_chip(.request_n_i(cascade_request_n_i[7:0]),.ei_n_i(cascade_high_eo_n_o),
    .g1_i(gates_i[0]),.g2_i(gates_i[1]),.g3_n_i(gates_i[2]),
    .g4_n_i(gates_i[3]),.g5_n_i(gates_i[4]),.a_o(cascade_low_a_o),
    .a_oe_o(cascade_low_oe_o),.eo_n_o(cascade_low_eo_n_o));
  logic [7:0] group_request_n, leaf_eo_n;
  logic [2:0] group_code;
  logic [2:0] leaf_code[8];
  logic [8:0] hierarchy_enable;
  assign group_request_n=~leaf_eo_n;
  for(genvar b=0;b<8;b=b+1) begin : hierarchy_leaf
    amd_am2913 leaf(.request_n_i(hierarchy_request_n_i[b*8+:8]),.ei_n_i(1'b0),
      .g1_i(1'b1),.g2_i(1'b1),.g3_n_i(1'b0),.g4_n_i(1'b0),.g5_n_i(1'b0),
      .a_o(leaf_code[b]),.a_oe_o(hierarchy_enable[b]),.eo_n_o(leaf_eo_n[b]));
  end
  amd_am2913 root(.request_n_i(group_request_n),.ei_n_i(1'b0),
    .g1_i(1'b1),.g2_i(1'b1),.g3_n_i(1'b0),.g4_n_i(1'b0),.g5_n_i(1'b0),
    .a_o(group_code),.a_oe_o(hierarchy_enable[8]),.eo_n_o(hierarchy_eo_n_o));
  assign hierarchy_a_o={group_code,leaf_code[group_code]} & {6{ &hierarchy_enable }};
endmodule
