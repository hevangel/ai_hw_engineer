// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls257 #(parameter integer T_PD = 0) (
    input tri p1, // S
    input tri p2, // I0a
    input tri p3, // I1a
    output tri p4, // Za
    input tri p5, // I0b
    input tri p6, // I1b
    output tri p7, // Zb
    input tri p8, // GND
    output tri p9, // Zd
    input tri p10, // I1d
    input tri p11, // I0d
    output tri p12, // Zc
    input tri p13, // I1c
    input tri p14, // I0c
    input tri p15, // OE
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    assign #(T_PD) p4 = powered ? (p15 ? 1'bz : (p1 ? p3 : p2)) : 1'bx;
    assign #(T_PD) p7 = powered ? (p15 ? 1'bz : (p1 ? p6 : p5)) : 1'bx;
    assign #(T_PD) p12 = powered ? (p15 ? 1'bz : (p1 ? p13 : p14)) : 1'bx;
    assign #(T_PD) p9 = powered ? (p15 ? 1'bz : (p1 ? p10 : p11)) : 1'bx;

endmodule
`default_nettype wire
