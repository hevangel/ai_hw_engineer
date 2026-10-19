// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls251 #(parameter integer T_PD = 0) (
    input tri p1, // I3
    input tri p2, // I2
    input tri p3, // I1
    input tri p4, // I0
    output tri p5, // Y
    output tri p6, // ~{Y}
    input tri p7, // ~{OE}
    input tri p8, // GND
    input tri p9, // S2
    input tri p10, // S1
    input tri p11, // S0
    input tri p12, // I7
    input tri p13, // I6
    input tri p14, // I5
    input tri p15, // I4
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [7:0] d;
    logic y;
    assign d = {p12,p13,p14,p15,p1,p2,p3,p4};
    assign y = d[{p9,p10,p11}];
    assign #(T_PD) p5 = powered ? (p7 ? 1'bz : y) : 1'bx;
    assign #(T_PD) p6 = powered ? (p7 ? 1'bz : ~y) : 1'bx;

endmodule
`default_nettype wire
