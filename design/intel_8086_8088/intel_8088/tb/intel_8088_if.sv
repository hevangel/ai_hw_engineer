`timescale 1ns / 1ps
interface intel_8088_if;
  logic clk = 0;
  logic reset = 1, min_mode = 1, ready = 1, intr = 0, nmi = 0, test_n = 1, hold = 0;
  logic [1:0] rqgt_n = 2'b11;
  logic [7:0] ad_in = 8'h20;
  logic [7:0] ad_out, high_address;
  logic [3:0] address_status;
  logic ad_oe, high_address_oe, address_status_oe, sso_oe, control_oe;
  logic sso_n, rd_n, wr_n, io_m, dt_r, den_n, ale, inta_n, hlda;
  logic [1:0] rqgt_n_o, rqgt_oe, qs;
  logic [2:0] status, phase;
  logic lock_n, halted, fault, retire;
  logic [15:0] ip, flags;
  logic [127:0] regs;
  logic [63:0] segs;
  logic [2:0] queue_count;
endinterface
