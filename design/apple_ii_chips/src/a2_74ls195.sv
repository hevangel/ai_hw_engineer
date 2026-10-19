// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls195 #(parameter integer T_PD = 0) (
    input tri p1, // ~{MR}
    input tri p2, // J
    input tri p3, // ~{K}
    input tri p4, // P0
    input tri p5, // P1
    input tri p6, // P2
    input tri p7, // P3
    input tri p8, // GND
    input tri p9, // ~{PE}
    input tri p10, // CP
    output tri p11, // ~{Q3}
    output tri p12, // Q3
    output tri p13, // Q2
    output tri p14, // Q1
    output tri p15, // Q0
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [3:0] q;
    always_ff @(posedge p10 or negedge p1) begin
        if (!p1) q <= 4'b0;
        else if (!p9) q <= {p7,p6,p5,p4};
        else q <= {q[2:0],((p2 & ~q[0]) | (p3 & q[0]))};
    end
    assign #(T_PD) p15 = powered ? (q[0]) : 1'bx;
    assign #(T_PD) p14 = powered ? (q[1]) : 1'bx;
    assign #(T_PD) p13 = powered ? (q[2]) : 1'bx;
    assign #(T_PD) p12 = powered ? (q[3]) : 1'bx;
    assign #(T_PD) p11 = powered ? (~q[3]) : 1'bx;

endmodule
`default_nettype wire
