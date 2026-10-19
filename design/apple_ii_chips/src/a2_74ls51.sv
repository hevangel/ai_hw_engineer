// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls51 #(parameter integer T_PD = 0) (
    input tri p1, // input
    input tri p2, // input
    input tri p3, // input
    input tri p4, // input
    input tri p5, // input
    output tri p6, // output
    input tri p7, // GND
    output tri p8, // output
    input tri p9, // input
    input tri p10, // input
    input tri p11, // input
    input tri p12, // input
    input tri p13, // input
    input tri p14 // VCC
);
    logic powered;
    assign powered = (p14 === 1'b1 && p7 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    assign #(T_PD) p6 = powered ? (~((p2 & p3) | (p4 & p5))) : 1'bx;
    assign #(T_PD) p8 = powered ? (~((p1 & p13 & p12) | (p9 & p10 & p11))) : 1'bx;

endmodule
`default_nettype wire
