`timescale 1ns/1ps
module tb_cascade(input logic clk_i,reset_i,host_chip_i,host_select_i,host_write_i,
 input logic [3:0] host_address_i,input logic [7:0] host_data_i,
 input logic [2:0] parent_request_i,input logic [3:0] child_request_i,
 input logic child_ready_i,output logic [7:0] host_data_o,output logic host_oe_o,
 output logic [1:0] hrq_o,aen_o,valid_o,adstb_o,eop_n_o,
 output logic [31:0] address_o,output logic [15:0] device_data_o,
 output logic [7:0] dack_o,strobes_o,output logic [3:0] channel_o);
 logic [7:0] data[0:1];logic [1:0] data_oe,unused_addr_oe;
 logic [3:0] requests[0:1];logic [1:0] grants;
 assign requests[0]={parent_request_i[2:1],hrq_o[1],parent_request_i[0]};
 assign requests[1]=child_request_i;
 assign grants[0]=hrq_o[0];assign grants[1]=grants[0]&&!dack_o[1];
 assign host_data_o=host_chip_i?data[1]:data[0];assign host_oe_o=data_oe[host_chip_i];
 assign device_data_o={data[1],data[0]};
 for(genvar i=0;i<2;i++)begin:devices
 amd_am9517 dma(.clk(clk_i),.reset_i(reset_i),.cs_n(!(host_select_i&&host_chip_i==1'(i))),
 .ior_n(!(host_select_i&&host_chip_i==1'(i)&&!host_write_i)),
 .iow_n(!(host_select_i&&host_chip_i==1'(i)&&host_write_i)),.reg_addr(host_address_i),
 .data_i(host_data_i),.data_o(data[i]),.data_oe(data_oe[i]),.dreq(requests[i]),
 .dack(dack_o[i*4+:4]),.hrq(hrq_o[i]),.hlda(grants[i]),.ready(i==0?1'b1:child_ready_i),.eop_n(1'b1),
 .eop_out_n(eop_n_o[i]),.dma_addr(address_o[i*16+:16]),.addr_oe(unused_addr_oe[i]),
 .adstb(adstb_o[i]),.aen(aen_o[i]),.memr_n(strobes_o[i*4+3]),.memw_n(strobes_o[i*4+2]),
 .dma_ior_n(strobes_o[i*4+1]),.dma_iow_n(strobes_o[i*4]),
 .transfer_valid(valid_o[i]),.transfer_channel(channel_o[i*2+:2]));
 end
endmodule
