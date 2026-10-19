// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls259 #(parameter integer T_PD = 0) (
    input tri p1, // A0
    input tri p2, // A1
    input tri p3, // A2
    output tri p4, // Q0
    output tri p5, // Q1
    output tri p6, // Q2
    output tri p7, // Q3
    input tri p8, // GND
    output tri p9, // Q4
    output tri p10, // Q5
    output tri p11, // Q6
    output tri p12, // Q7
    input tri p13, // D
    input tri p14, // E
    input tri p15, // Clr
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [7:0] q;
    always_latch begin
        if (!p15) begin
            q = 8'b0;
            if (!p14) q[{p3,p2,p1}] = p13;
        end else if (!p14) q[{p3,p2,p1}] = p13;
    end
    assign #(T_PD) p4 = powered ? (q[0]) : 1'bx;
    assign #(T_PD) p5 = powered ? (q[1]) : 1'bx;
    assign #(T_PD) p6 = powered ? (q[2]) : 1'bx;
    assign #(T_PD) p7 = powered ? (q[3]) : 1'bx;
    assign #(T_PD) p9 = powered ? (q[4]) : 1'bx;
    assign #(T_PD) p10 = powered ? (q[5]) : 1'bx;
    assign #(T_PD) p11 = powered ? (q[6]) : 1'bx;
    assign #(T_PD) p12 = powered ? (q[7]) : 1'bx;

endmodule
`default_nettype wire
