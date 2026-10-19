// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls04 #(parameter integer T_PD = 0) (
    input tri p1, // input
    output tri p2, // output
    input tri p3, // input
    output tri p4, // output
    input tri p5, // input
    output tri p6, // output
    input tri p7, // GND
    output tri p8, // output
    input tri p9, // input
    output tri p10, // output
    input tri p11, // input
    output tri p12, // output
    input tri p13, // input
    input tri p14 // VCC
);
    logic powered;
    assign powered = (p14 === 1'b1 && p7 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    assign #(T_PD) p2 = powered ? (~p1) : 1'bx;
    assign #(T_PD) p4 = powered ? (~p3) : 1'bx;
    assign #(T_PD) p6 = powered ? (~p5) : 1'bx;
    assign #(T_PD) p8 = powered ? (~p9) : 1'bx;
    assign #(T_PD) p10 = powered ? (~p11) : 1'bx;
    assign #(T_PD) p12 = powered ? (~p13) : 1'bx;

endmodule
`default_nettype wire
