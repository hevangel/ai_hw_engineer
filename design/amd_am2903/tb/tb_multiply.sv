// AMD Figures15–19: actual four-slice 16-bit array and Am2910 controller.
module tb_multiply (
  input logic cp_i, controller_cp_i,
  input logic [8:0] instruction_i,
  input logic [3:0] a_i,b_i,controller_instruction_i,
  input logic [11:0] controller_d_i,
  input logic [15:0] external_y_i,
  input logic oe_y_n_i,ien_n_i,auto_write_i,we_n_i,cn_i,cn_from_z_i,
  output logic [15:0] y_o,db_o,
  output logic [11:0] next_address_o,
  output logic controller_full_n_o,controller_pl_n_o,controller_map_n_o,controller_vect_n_o,controller_y_oe_o,
  output logic [3:0] write_n_o,db_enabled_o,y_enabled_o,gn_o,povr_o,write_enabled_o,
  output logic [15:0] shift_o,shift_enable_o,
  output logic zero_bus_o,cn16_o,overflow_o
);
  /* verilator lint_off UNOPTFLAT */
  logic [4:0] carry;
  logic z_bus;
  /* verilator lint_on UNOPTFLAT */
  // Mode-selectable open-collector communication is acyclic per legal
  // instruction; a mode-insensitive structural graph joins opposite paths.
  /* verilator lint_off UNOPTFLAT */
  logic [3:0] z_pull;
  /* verilator lint_on UNOPTFLAT */
  logic [3:0] sio0;
  logic [2:0] sio3,qio3;
  logic [3:1] qio0;
  logic [3:0] sio0_input,sio3_input,qio0_input,qio3_input;
  logic write_enable;
  assign write_enable=auto_write_i ? write_n_o[0]:we_n_i;
  assign z_bus=!(|z_pull);
  assign zero_bus_o=z_bus;
  assign carry[0]=cn_from_z_i ? z_bus:cn_i;
  assign cn16_o=carry[4];assign overflow_o=povr_o[3];
  assign sio0_input={sio3[2:0],1'b0};
  assign sio3_input={1'b0,sio0[3:1]};
  assign qio0_input={qio3[2:0],1'b0};
  assign qio3_input={sio0[0],qio0[3:1]};
  for(genvar i=0;i<4;i++) begin: slices
    assign sio0[i]=shift_o[4*i];
    if(i<3) begin: upper_links
      assign sio3[i]=shift_o[4*i+1];assign qio3[i]=shift_o[4*i+3];
    end
    if(i>0) begin: lower_links
      assign qio0[i]=shift_o[4*i+2];
    end
    amd_am2903 dut (
      .cp_i(cp_i),.instruction_i(instruction_i),.a_i(a_i),.b_i(b_i),
      .da_i(4'b0),.db_i(4'b0),.y_i(external_y_i[4*i+:4]),
      .ea_i(1'b0),.oe_b_n_i(1'b0),.oe_y_n_i(oe_y_n_i),.we_n_i(write_enable),.ien_n_i(ien_n_i),.cn_i(carry[i]),
      .lss_n_i(i!=0),.mss_n_i(i!=3),.z_i(z_bus),
      .sio0_i(sio0_input[i]),.sio3_i(sio3_input[i]),.qio0_i(qio0_input[i]),.qio3_i(qio3_input[i]),
      .y_o(y_o[4*i+:4]),.db_o(db_o[4*i+:4]),.y_oe_o(y_enabled_o[i]),.db_oe_o(db_enabled_o[i]),
      .write_n_o(write_n_o[i]),.write_oe_o(write_enabled_o[i]),.cn4_o(carry[i+1]),.gn_o(gn_o[i]),.povr_o(povr_o[i]),
      .z_pull_low_o(z_pull[i]),.shift_o(shift_o[4*i+:4]),.shift_oe_o(shift_enable_o[4*i+:4])
    );
  end
  amd_am2910 controller (
    .cp_i(controller_cp_i),.instruction_i(controller_instruction_i),.d_i(controller_d_i),
    .cc_n_i(1'b0),.ccen_n_i(1'b1),.ci_i(1'b1),.rld_n_i(1'b1),.oe_n_i(1'b0),
    .y_o(next_address_o),.y_oe_o(controller_y_oe_o),.full_n_o(controller_full_n_o),
    .pl_n_o(controller_pl_n_o),.map_n_o(controller_map_n_o),.vect_n_o(controller_vect_n_o)
  );
endmodule
