`timescale 1ns/1ps
module tb_top (
 input logic clk_i,reset_n_i,ram_ready_i,
 input logic [7:0] ram_data_i,
 output logic req_o,write_o,io_o,retire_o,halted_o,fault_o,inte_o,
 output logic [15:0] address_o,pc_o,sp_o,
 output logic [7:0] write_data_o,read_data_o,flags_o,status_o,
 output logic [55:0] regs_o
);
 logic pause_n,ready,unused_bus_enable,unused_end,unused_service,unused_intack,unused_hlda;
 logic [7:0] apu_data;
 assign read_data_o=io_o?apu_data:ram_data_i;
 assign ready=io_o?pause_n:ram_ready_i;
 amd_am9080 cpu(.clk(clk_i),.rst_n(reset_n_i),.bus_ready_i(ready),.bus_rdata_i(read_data_o),
  .int_i(1'b0),.hold_i(1'b0),.bus_req_o(req_o),.bus_write_o(write_o),.bus_io_o(io_o),
  .bus_intack_o(unused_intack),.bus_addr_o(address_o),.bus_wdata_o(write_data_o),.bus_status_o(status_o),
  .inte_o(inte_o),.hlda_o(unused_hlda),.halted_o(halted_o),.retire_o(retire_o),.fault_o(fault_o),
  .pc_o(pc_o),.sp_o(sp_o),.regs_o(regs_o),.flags_o(flags_o));
 amd_am9511 apu(.clk_i(clk_i),.reset_i(!reset_n_i),.cs_n_i(!(req_o&&io_o)),
  .rd_n_i(!(req_o&&io_o&&!write_o)),.wr_n_i(!(req_o&&io_o&&write_o)),.cd_i(address_o[0]),
  .eack_n_i(1'b1),.svack_n_i(1'b1),.data_i(write_data_o),.data_o(apu_data),
  .data_oe_o(unused_bus_enable),.pause_n_o(pause_n),.end_pull_low_o(unused_end),.svreq_o(unused_service));
endmodule
