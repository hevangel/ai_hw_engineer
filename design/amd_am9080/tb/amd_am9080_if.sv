`timescale 1ns/1ps
interface amd_am9080_if;
  logic clk=0, rst_n=0, ready=0, int_req=0, hold_req=0;
  logic [7:0] rdata=0, wdata, status, flags;
  logic req, write_en, io, intack, inte, hlda, halted, retire, fault;
  logic [15:0] addr, pc, sp;
  logic [55:0] regs;
endinterface
