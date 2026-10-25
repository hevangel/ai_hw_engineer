`timescale 1ns/1ps
`default_nettype none
module ttl_74x1395 (
    input  logic [1:0] a_in,
    input  logic [1:0] b_bus_in,
    input  logic [1:0] oeab_n,
    input  logic [1:0] oeby_n,
    input  logic [1:0] tc,
    input  logic       erc,
    output logic [1:0] b_output_enable,
    output logic [1:0] b_output_data,
    output logic [1:0] y_output_enable,
    output logic [1:0] y_output_data,
    output logic       b_edge_fast
);
    assign b_output_enable = ~oeab_n;
    assign b_output_data = a_in ^ ~tc;
    assign y_output_enable = ~oeby_n;
    assign y_output_data = b_bus_in ^ ~tc;
    assign b_edge_fast = ~erc;
endmodule
`default_nettype wire
