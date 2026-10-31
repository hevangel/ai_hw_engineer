`timescale 1ns/1ps
`default_nettype none
module ttl_74x1394 (
    input  logic [1:0] a_in,
    input  logic [1:0] b_bus_in,
    input  logic       oeab_n,
    input  logic       oeby_n,
    input  logic       tc,
    input  logic       erc,
    output logic [1:0] b_output_enable,
    output logic [1:0] b_output_data,
    output logic [1:0] y_output_enable,
    output logic [1:0] y_output_data,
    output logic       b_edge_fast
);
    assign b_output_enable = {2{~oeab_n}};
    assign b_output_data = tc ? a_in : ~a_in;
    assign y_output_enable = {2{~oeby_n}};
    assign y_output_data = tc ? b_bus_in : ~b_bus_in;
    assign b_edge_fast = erc;
endmodule
`default_nettype wire
