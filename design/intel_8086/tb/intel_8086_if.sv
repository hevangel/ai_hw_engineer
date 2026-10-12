`timescale 1ns / 1ps
interface intel_8086_if;
  logic clk = 0, rst_n = 0, ready = 0;
  logic [15:0] rdata = 0, wdata, ip, flags;
  logic [19:0] addr;
  logic [ 1:0] be;
  logic req, write_en, fetch, halted, fault, retire;
  logic [127:0] regs;
  logic [ 63:0] segs;
endinterface
