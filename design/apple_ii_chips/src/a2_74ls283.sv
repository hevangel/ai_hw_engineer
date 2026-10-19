// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls283 #(parameter integer T_PD = 0) (
    output tri p1, // S2
    input tri p2, // B2
    input tri p3, // A2
    output tri p4, // S1
    input tri p5, // A1
    input tri p6, // B1
    input tri p7, // C0
    input tri p8, // GND
    output tri p9, // C4
    output tri p10, // S4
    input tri p11, // B4
    input tri p12, // A4
    output tri p13, // S3
    input tri p14, // A3
    input tri p15, // B3
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [4:0] sum;
    assign sum = {1'b0,p12,p14,p3,p5} + {1'b0,p11,p15,p2,p6} + {4'b0,p7};
    assign #(T_PD) p4 = powered ? (sum[0]) : 1'bx;
    assign #(T_PD) p1 = powered ? (sum[1]) : 1'bx;
    assign #(T_PD) p13 = powered ? (sum[2]) : 1'bx;
    assign #(T_PD) p10 = powered ? (sum[3]) : 1'bx;
    assign #(T_PD) p9 = powered ? (sum[4]) : 1'bx;

endmodule
`default_nettype wire
