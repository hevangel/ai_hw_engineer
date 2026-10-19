// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls166 #(parameter integer T_PD = 0) (
    input tri p1, // Ds
    input tri p2, // A
    input tri p3, // B
    input tri p4, // C
    input tri p5, // D
    input tri p6, // CE
    input tri p7, // Clk
    input tri p8, // GND
    input tri p9, // Clr
    input tri p10, // E
    input tri p11, // F
    input tri p12, // G
    output tri p13, // Qh
    input tri p14, // H
    input tri p15, // PE
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [7:0] q;
    logic cp;
    assign cp = p7 | p6;
    always_ff @(posedge cp or negedge p9) begin
        if (!p9) q <= 8'b0;
        else if (!p15) q <= {p14,p12,p11,p10,p5,p4,p3,p2};
        else q <= {q[6:0],p1};
    end
    assign #(T_PD) p13 = powered ? (q[7]) : 1'bx;

endmodule
`default_nettype wire
