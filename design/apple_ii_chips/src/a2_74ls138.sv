// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls138 #(parameter integer T_PD = 0) (
    input tri p1, // A0
    input tri p2, // A1
    input tri p3, // A2
    input tri p4, // E1
    input tri p5, // E2
    input tri p6, // E3
    output tri p7, // O7
    input tri p8, // GND
    output tri p9, // O6
    output tri p10, // O5
    output tri p11, // O4
    output tri p12, // O3
    output tri p13, // O2
    output tri p14, // O1
    output tri p15, // O0
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    assign #(T_PD) p15 = powered ? (~(p6 & ~p4 & ~p5 & ({p3,p2,p1} == 3'd0))) : 1'bx;
    assign #(T_PD) p14 = powered ? (~(p6 & ~p4 & ~p5 & ({p3,p2,p1} == 3'd1))) : 1'bx;
    assign #(T_PD) p13 = powered ? (~(p6 & ~p4 & ~p5 & ({p3,p2,p1} == 3'd2))) : 1'bx;
    assign #(T_PD) p12 = powered ? (~(p6 & ~p4 & ~p5 & ({p3,p2,p1} == 3'd3))) : 1'bx;
    assign #(T_PD) p11 = powered ? (~(p6 & ~p4 & ~p5 & ({p3,p2,p1} == 3'd4))) : 1'bx;
    assign #(T_PD) p10 = powered ? (~(p6 & ~p4 & ~p5 & ({p3,p2,p1} == 3'd5))) : 1'bx;
    assign #(T_PD) p9 = powered ? (~(p6 & ~p4 & ~p5 & ({p3,p2,p1} == 3'd6))) : 1'bx;
    assign #(T_PD) p7 = powered ? (~(p6 & ~p4 & ~p5 & ({p3,p2,p1} == 3'd7))) : 1'bx;

endmodule
`default_nettype wire
