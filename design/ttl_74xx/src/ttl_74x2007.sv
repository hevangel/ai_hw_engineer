`timescale 1ns/1ps
`default_nettype none
module ttl_74x2007 (
    input  logic       en1,
    input  logic [1:0] bi_1_2,
    output logic [1:0] ao_1_2,
    input  logic       en2,
    input  logic [1:0] bi_3_4,
    output logic [1:0] ao_3_4,
    input  logic       bi_9,
    output logic       ao_9,
    input  logic [1:0] bi_5_6,
    input  logic [1:0] a_5_6_ext_drive,
    input  logic [1:0] a_5_6_ext_data,
    output logic [1:0] a_5_6_drive_low,
    output logic [1:0] a_5_6_bus,
    output logic [1:0] bo_7_drive_low,
    input  logic       ai_8,
    output logic       bo_8_drive_low,
    input  logic [1:0] ai_10,
    output logic [1:0] bo_10_drive_low,
    input  logic       bi_11,
    input  logic       a_11_ext_drive,
    input  logic       a_11_ext_data,
    output logic       a_11_drive_low,
    output logic       a_11_bus,
    output logic       bo_11_drive_low
);
    assign ao_1_2 = en1 ? bi_1_2 : 2'b11;
    assign ao_3_4 = en2 ? bi_3_4 : 2'b11;
    assign ao_9 = bi_9;

    assign a_5_6_drive_low = {2{en2}} & ~bi_5_6;
    assign a_5_6_bus = ~a_5_6_drive_low
                     & ((a_5_6_ext_drive & a_5_6_ext_data) | ~a_5_6_ext_drive);
    assign bo_7_drive_low = bi_5_6 & ~a_5_6_bus;

    assign bo_8_drive_low = ~ai_8;
    assign bo_10_drive_low = ~(ai_10 & {2{bi_9}});

    assign a_11_drive_low = bi_11;
    assign a_11_bus = a_11_drive_low
                    ? 1'b0
                    : (a_11_ext_drive ? a_11_ext_data : 1'b1);
    assign bo_11_drive_low = a_11_bus;
endmodule
`default_nettype wire
