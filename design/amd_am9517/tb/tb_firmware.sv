`timescale 1ns/1ps
module tb_firmware(input logic clk_i,reset_n_i,ram_ready_i,dma_ready_i,
 input logic [7:0] ram_data_i,dma_memory_data_i,input logic [3:0] dreq_i,
 output logic req_o,write_o,io_o,retire_o,halted_o,fault_o,inte_o,hlda_o,dma_hrq_o,
 output logic [15:0] address_o,pc_o,sp_o,dma_address_o,
 output logic [7:0] write_data_o,read_data_o,flags_o,status_o,
 output logic [55:0] regs_o,output logic [3:0] dack_o,
 output logic dma_valid_o,dma_aen_o,dma_memr_n_o,dma_memw_n_o,dma_ior_n_o,dma_iow_n_o,
 output logic [1:0] dma_channel_o,output logic dma_eop_n_o,dma_data_oe_o);
 logic unused_intack,unused_addr_oe,unused_adstb;
 logic [7:0] dma_data;
 assign read_data_o=io_o?dma_data:ram_data_i;
 amd_am9080 cpu(.clk(clk_i),.rst_n(reset_n_i),.bus_ready_i(io_o?1'b1:ram_ready_i),.bus_rdata_i(read_data_o),
 .int_i(1'b0),.hold_i(dma_hrq_o),.bus_req_o(req_o),.bus_write_o(write_o),.bus_io_o(io_o),
 .bus_intack_o(unused_intack),.bus_addr_o(address_o),.bus_wdata_o(write_data_o),.bus_status_o(status_o),
 .inte_o(inte_o),.hlda_o(hlda_o),.halted_o(halted_o),.retire_o(retire_o),.fault_o(fault_o),
 .pc_o(pc_o),.sp_o(sp_o),.regs_o(regs_o),.flags_o(flags_o));
 amd_am9517 dma(.clk(clk_i),.reset_i(!reset_n_i),.cs_n(!(req_o&&io_o&&address_o[7:4]==0)),
 .ior_n(!(req_o&&io_o&&!write_o)),.iow_n(!(req_o&&io_o&&write_o)),.reg_addr(address_o[3:0]),
 .data_i(dma_aen_o?dma_memory_data_i:write_data_o),.data_o(dma_data),.data_oe(dma_data_oe_o),
 .dreq(dreq_i),.dack(dack_o),.hrq(dma_hrq_o),.hlda(hlda_o),.ready(dma_ready_i),.eop_n(1'b1),
 .eop_out_n(dma_eop_n_o),.dma_addr(dma_address_o),.addr_oe(unused_addr_oe),.adstb(unused_adstb),
 .aen(dma_aen_o),.memr_n(dma_memr_n_o),.memw_n(dma_memw_n_o),.dma_ior_n(dma_ior_n_o),.dma_iow_n(dma_iow_n_o),
 .transfer_valid(dma_valid_o),.transfer_channel(dma_channel_o));
endmodule
