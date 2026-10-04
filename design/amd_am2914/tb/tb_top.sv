module tb_top (
  input logic cp_i,
  input logic [7:0] p_n_i, m_i,
  input logic [2:0] s_i,
  input logic [3:0] instruction_i,
  input logic ie_n_i, lb_i, ge_n_i, gar_n_i, id_n_i,
  output logic [7:0] m_o,
  output logic [2:0] s_o, v_o,
  output logic m_oe_o, s_oe_o, v_oe_o,
  output logic irq_pull_low_o, gs_n_o, gas_n_o, rd_n_o, pd_o, sv_n_o,
  input logic board_cp_i,
  input logic [63:0] board_p_n_i,
  input logic [7:0] board_m_i,
  input logic [5:0] board_s_i,
  input logic [3:0] board_instruction_i,
  input logic board_ie_n_i, board_lb_i,
  output logic [5:0] board_v_o, board_status_o,
  output logic [7:0] board_v_oe_o, board_s_oe_o, board_gs_n_o, board_sv_n_o,
  output logic board_irq_o, board_vector_high_oe_o, board_status_high_oe_o,
  output logic [63:0] board_mask_o,
  output logic [7:0] board_m_oe_o, board_pd_o,
  output logic [1:0] board_expander_eo_o,
  output logic [7:0] board_gas_n_o
);
  amd_am2914 dut(.cp_i(cp_i),.p_n_i(p_n_i),.m_i(m_i),.s_i(s_i),
    .instruction_i(instruction_i),.ie_n_i(ie_n_i),.lb_i(lb_i),.ge_n_i(ge_n_i),
    .gar_n_i(gar_n_i),.id_n_i(id_n_i),.m_o(m_o),.s_o(s_o),.v_o(v_o),
    .m_oe_o(m_oe_o),.s_oe_o(s_oe_o),.v_oe_o(v_oe_o),.irq_pull_low_o(irq_pull_low_o),
    .gs_n_o(gs_n_o),.gas_n_o(gas_n_o),.rd_n_o(rd_n_o),.pd_o(pd_o),.sv_n_o(sv_n_o));
  logic [7:0] rd_bus, irq_bus;
  logic [2:0] local_vector[8],local_status[8];
  logic [2:0] high_vector,high_status;
  // Original Figures6/9/10: RD cascades high->low; GAS low->high.
  // Scalar per-instance links keep this physical connection graph explicit.
  for(genvar b=0;b<8;b=b+1)begin : controller_group
    logic group_id,group_gar;
    if(b==7)begin : highest_group assign group_id=board_sv_n_o[7];end
    else begin : lower_group assign group_id=rd_bus[b+1];end
    if(b==0)begin : lowest_group assign group_gar=1'b0;end
    else begin : upper_group assign group_gar=board_gas_n_o[b-1];end
    amd_am2914 chip(.cp_i(board_cp_i),.p_n_i(board_p_n_i[b*8+:8]),.m_i(board_m_i),
      .s_i(board_s_i[2:0]),.instruction_i(board_instruction_i),.ie_n_i(board_ie_n_i),.lb_i(board_lb_i),
      .ge_n_i(board_s_i[5:3]!=3'(b)),.gar_n_i(group_gar),.id_n_i(group_id),
      .m_o(board_mask_o[b*8+:8]),.m_oe_o(board_m_oe_o[b]),.s_o(local_status[b]),.s_oe_o(board_s_oe_o[b]),
      .v_o(local_vector[b]),.v_oe_o(board_v_oe_o[b]),.irq_pull_low_o(irq_bus[b]),
      .gs_n_o(board_gs_n_o[b]),.gas_n_o(board_gas_n_o[b]),.rd_n_o(rd_bus[b]),.pd_o(board_pd_o[b]),.sv_n_o(board_sv_n_o[b]));
  end
  always_comb begin
    board_v_o={high_vector,local_vector[high_vector]};
    board_status_o={high_status,local_status[high_status]};
    if(board_v_oe_o==0)board_v_o={high_vector,3'b000};
    if(board_s_oe_o==0)board_status_o={high_status,3'b000};
    board_irq_o=|irq_bus;
  end
  amd_am2913 vector_expander(.request_n_i(rd_bus),.ei_n_i(1'b0),
    .g1_i(!board_ie_n_i),.g2_i(board_instruction_i[0]),.g3_n_i(board_instruction_i[1]),
    .g4_n_i(!board_instruction_i[2]),.g5_n_i(board_instruction_i[3]),
    .a_o(high_vector),.a_oe_o(board_vector_high_oe_o),.eo_n_o(board_expander_eo_o[0]));
  amd_am2913 status_expander(.request_n_i(board_gs_n_o),.ei_n_i(1'b0),
    .g1_i(!board_ie_n_i),.g2_i(board_instruction_i[1]),.g3_n_i(board_instruction_i[0]),
    .g4_n_i(!board_instruction_i[2]),.g5_n_i(board_instruction_i[3]),
    .a_o(high_status),.a_oe_o(board_status_high_oe_o),.eo_n_o(board_expander_eo_o[1]));
endmodule
