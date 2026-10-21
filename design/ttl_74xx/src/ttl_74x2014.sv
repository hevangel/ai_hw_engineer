`timescale 1ns/1ps
`default_nettype none
module ttl_74x2014 (
    input  logic       dir,
    input  logic [3:0] a_bus_in,
    input  logic [3:0] b_bus_in,
    output logic [3:0] a_output_enable,
    output logic [3:0] a_output_data,
    output logic [3:0] b_output_enable,
    output logic [3:0] b_drive_low
);
    assign a_output_enable = {4{~dir}};
    assign a_output_data = dir ? 4'b0000 : b_bus_in;
    assign b_output_enable = {4{dir}};
    assign b_drive_low = {4{dir}} & ~a_bus_in;
endmodule
`default_nettype wire
