// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_8t97_appleii #(parameter integer T_PD = 0) (
    input tri p1, // DIS1
    input tri p2, // I1
    output tri p3, // Y1
    input tri p4, // I2
    output tri p5, // Y2
    input tri p6, // I3
    output tri p7, // Y3
    input tri p8, // GND
    output tri p9, // Y4
    input tri p10, // I4
    output tri p11, // Y5
    input tri p12, // I5
    output tri p13, // Y6
    input tri p14, // I6
    input tri p15, // DIS2
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    assign #(T_PD) p3 = powered ? (p1 ? 1'bz : p2) : 1'bx;
    assign #(T_PD) p5 = powered ? (p1 ? 1'bz : p4) : 1'bx;
    assign #(T_PD) p7 = powered ? (p1 ? 1'bz : p6) : 1'bx;
    assign #(T_PD) p9 = powered ? (p1 ? 1'bz : p10) : 1'bx;
    assign #(T_PD) p11 = powered ? (p15 ? 1'bz : p12) : 1'bx;
    assign #(T_PD) p13 = powered ? (p15 ? 1'bz : p14) : 1'bx;

endmodule
`default_nettype wire
