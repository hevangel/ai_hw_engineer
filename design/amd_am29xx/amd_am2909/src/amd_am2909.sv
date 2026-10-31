`timescale 1ns/1ps
module amd_am2909 (
    input logic cp_i,
    input logic [1:0] select_i,
    input logic [3:0] d_i,r_i,or_i,
    input logic re_n_i,fe_n_i,push_i,zero_n_i,oe_n_i,cn_i,
    output logic [3:0] y_o,
    output logic y_oe_o,cn4_o
);
  logic [3:0] upc,address_register,stack [0:3],selected_address;
  logic [1:0] sp,next_sp;
  logic [4:0] incremented;
  assign next_sp=push_i ? sp+2'd1:sp-2'd1;
  always_comb begin
    case (select_i)
      2'd0: selected_address=upc;
      2'd1: selected_address=address_register;
      2'd2: selected_address=stack[sp];
      2'd3: selected_address=d_i;
      default: selected_address=0;
    endcase
    y_o=zero_n_i ? (selected_address|or_i):4'b0;
    incremented={1'b0,y_o}+5'(cn_i);
    cn4_o=incremented[4]; y_oe_o=!oe_n_i;
  end
  always_ff @(posedge cp_i) begin
    upc<=incremented[3:0];
    if (!re_n_i) address_register<=r_i;
    if (!fe_n_i) begin
      sp<=next_sp;
      if (push_i) stack[next_sp]<=upc;
    end
  end
`ifdef FORMAL
  `include "amd_am2909_props.sv"
`endif
endmodule
