// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls139 #(parameter integer T_PD = 0) (
    input tri p1, // E
    input tri p2, // A0
    input tri p3, // A1
    output tri p4, // O0
    output tri p5, // O1
    output tri p6, // O2
    output tri p7, // O3
    input tri p8, // GND
    output tri p9, // O3
    output tri p10, // O2
    output tri p11, // O1
    output tri p12, // O0
    input tri p13, // A1
    input tri p14, // A0
    input tri p15, // E
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    assign #(T_PD) p4 = powered ? (~(~p1 & ({p3,p2} == 2'd0))) : 1'bx;
    assign #(T_PD) p5 = powered ? (~(~p1 & ({p3,p2} == 2'd1))) : 1'bx;
    assign #(T_PD) p6 = powered ? (~(~p1 & ({p3,p2} == 2'd2))) : 1'bx;
    assign #(T_PD) p7 = powered ? (~(~p1 & ({p3,p2} == 2'd3))) : 1'bx;
    assign #(T_PD) p12 = powered ? (~(~p15 & ({p13,p14} == 2'd0))) : 1'bx;
    assign #(T_PD) p11 = powered ? (~(~p15 & ({p13,p14} == 2'd1))) : 1'bx;
    assign #(T_PD) p10 = powered ? (~(~p15 & ({p13,p14} == 2'd2))) : 1'bx;
    assign #(T_PD) p9 = powered ? (~(~p15 & ({p13,p14} == 2'd3))) : 1'bx;

endmodule
`default_nettype wire
