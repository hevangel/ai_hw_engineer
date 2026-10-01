// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls194 #(parameter integer T_PD = 0) (
    input tri p1, // Mr
    input tri p2, // Dsr
    input tri p3, // P0
    input tri p4, // P1
    input tri p5, // P2
    input tri p6, // P3
    input tri p7, // Dsl
    input tri p8, // GND
    input tri p9, // S0
    input tri p10, // S1
    input tri p11, // Cp
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
    always_ff @(posedge p11 or negedge p1) begin
        if (!p1) q <= 4'b0;
        else case ({p10,p9})
            2'b00: q <= q;
            2'b01: q <= {q[2:0],p2};
            2'b10: q <= {p7,q[3:1]};
            2'b11: q <= {p6,p5,p4,p3};
            default: q <= 'x;
        endcase
    end
    assign #(T_PD) p15 = powered ? (q[0]) : 1'bx;
    assign #(T_PD) p14 = powered ? (q[1]) : 1'bx;
    assign #(T_PD) p13 = powered ? (q[2]) : 1'bx;
    assign #(T_PD) p12 = powered ? (q[3]) : 1'bx;

endmodule
`default_nettype wire
