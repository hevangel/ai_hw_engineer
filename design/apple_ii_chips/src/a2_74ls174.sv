// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls174 #(parameter integer T_PD = 0) (
    input tri p1, // ~{Mr}
    output tri p2, // Q0
    input tri p3, // D0
    input tri p4, // D1
    output tri p5, // Q1
    input tri p6, // D2
    output tri p7, // Q2
    input tri p8, // GND
    input tri p9, // Cp
    output tri p10, // Q3
    input tri p11, // D3
    output tri p12, // Q4
    input tri p13, // D4
    input tri p14, // D5
    output tri p15, // Q5
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [5:0] q;
    always_ff @(posedge p9 or negedge p1) begin
        if (!p1) q <= '0;
        else q <= {p14,p13,p11,p6,p4,p3};
    end
    assign #(T_PD) p2 = powered ? (q[0]) : 1'bx;
    assign #(T_PD) p5 = powered ? (q[1]) : 1'bx;
    assign #(T_PD) p7 = powered ? (q[2]) : 1'bx;
    assign #(T_PD) p10 = powered ? (q[3]) : 1'bx;
    assign #(T_PD) p12 = powered ? (q[4]) : 1'bx;
    assign #(T_PD) p15 = powered ? (q[5]) : 1'bx;

endmodule
`default_nettype wire
