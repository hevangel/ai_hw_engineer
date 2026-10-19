// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls02 #(parameter integer T_PD = 0) (
    output tri p1, // output
    input tri p2, // input
    input tri p3, // input
    output tri p4, // output
    input tri p5, // input
    input tri p6, // input
    input tri p7, // GND
    input tri p8, // input
    input tri p9, // input
    output tri p10, // output
    input tri p11, // input
    input tri p12, // input
    output tri p13, // output
    input tri p14 // VCC
);
    logic powered;
    assign powered = (p14 === 1'b1 && p7 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    assign #(T_PD) p1 = powered ? (~(p2 | p3)) : 1'bx;
    assign #(T_PD) p4 = powered ? (~(p5 | p6)) : 1'bx;
    assign #(T_PD) p10 = powered ? (~(p8 | p9)) : 1'bx;
    assign #(T_PD) p13 = powered ? (~(p11 | p12)) : 1'bx;

endmodule
`default_nettype wire
