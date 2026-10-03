`timescale 1ns/1ps
interface intel_8237_if(input logic clk);
    logic rst_n = 0, cs_n = 1, ior_n = 1, iow_n = 1;
    logic [3:0] reg_addr = 0, dreq = 0, dack;
    logic [7:0] data_i, data_o, cpu_data = 0;
    logic data_oe, hrq, hlda = 0, ready = 1, eop_n = 1, eop_out_n;
    logic [15:0] dma_addr;
    logic addr_oe, adstb, aen, memr_n, memw_n, dma_ior_n, dma_iow_n;
    logic transfer_valid;
    logic [1:0] transfer_channel;
endinterface
