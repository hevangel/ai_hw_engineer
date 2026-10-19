// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls153 #(parameter integer T_PD = 0) (
    input tri p1, // Ea
    input tri p2, // S1
    input tri p3, // I3a
    input tri p4, // I2a
    input tri p5, // I1a
    input tri p6, // I0a
    output tri p7, // Za
    input tri p8, // GND
    output tri p9, // Zb
    input tri p10, // I0b
    input tri p11, // I1b
    input tri p12, // I2b
    input tri p13, // I3b
    input tri p14, // S0
    input tri p15, // Eb
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [3:0] a, b;
    assign a = {p3,p4,p5,p6};
    assign b = {p13,p12,p11,p10};
    assign #(T_PD) p7 = powered ? (~p1 & a[{p2,p14}]) : 1'bx;
    assign #(T_PD) p9 = powered ? (~p15 & b[{p2,p14}]) : 1'bx;

endmodule
`default_nettype wire
