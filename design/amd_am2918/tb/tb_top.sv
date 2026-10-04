module tb_top (
  input logic cp_i,
  input logic [3:0] d_i,
  input logic oe_n_i,
  output logic [3:0] q_o, y_o,
  output logic y_oe_o,
  input logic bridge_cp_i,
  input logic [3:0] a_external_i, b_external_i,
  input logic [1:0] bridge_oe_n_i,
  output logic [3:0] a_bus_o,b_bus_o,a_stored_o,b_stored_o,
  output logic [1:0] bridge_enable_o,
  input logic serial_cp_i,serial_i,serial_oe_n_i,
  output logic [7:0] serial_q_o,serial_y_o,
  output logic [1:0] serial_enable_o
);
  amd_am2918 dut(.*);
  logic [3:0] a_y,b_y;
  // MPR-188: one internal driver per bus; external inputs are used when the
  // corresponding internal Y driver is released. Tests respect bus ownership.
  assign a_bus_o=bridge_enable_o[1] ? b_y:a_external_i;
  assign b_bus_o=bridge_enable_o[0] ? a_y:b_external_i;
  amd_am2918 a_register(.cp_i(bridge_cp_i),.d_i(a_bus_o),.oe_n_i(bridge_oe_n_i[0]),
    .q_o(a_stored_o),.y_o(a_y),.y_oe_o(bridge_enable_o[0]));
  amd_am2918 b_register(.cp_i(bridge_cp_i),.d_i(b_bus_o),.oe_n_i(bridge_oe_n_i[1]),
    .q_o(b_stored_o),.y_o(b_y),.y_oe_o(bridge_enable_o[1]));
  // MPR-189: the first Q3 feeds the second D0; each other Q feeds next D.
  amd_am2918 serial_low(.cp_i(serial_cp_i),.d_i({serial_q_o[2:0],serial_i}),.oe_n_i(serial_oe_n_i),
    .q_o(serial_q_o[3:0]),.y_o(serial_y_o[3:0]),.y_oe_o(serial_enable_o[0]));
  amd_am2918 serial_high(.cp_i(serial_cp_i),.d_i(serial_q_o[6:3]),.oe_n_i(serial_oe_n_i),
    .q_o(serial_q_o[7:4]),.y_o(serial_y_o[7:4]),.y_oe_o(serial_enable_o[1]));
endmodule
