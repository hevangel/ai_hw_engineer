// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls175 #(parameter integer T_PD = 0) (
    input tri p1, // ~{CLR}
    output tri p2, // 1Q
    output tri p3, // ~{1Q}
    input tri p4, // 1D
    input tri p5, // 2D
    output tri p6, // ~{2Q}
    output tri p7, // 2Q
    input tri p8, // GND
    input tri p9, // CLK
    output tri p10, // 3Q
    output tri p11, // ~{3Q}
    input tri p12, // 3D
    input tri p13, // 4D
    output tri p14, // ~{4Q}
    output tri p15, // 4Q
    input tri p16 // VCC
);
    logic powered;
    assign powered = (p16 === 1'b1 && p8 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic [3:0] q;
    always_ff @(posedge p9 or negedge p1) begin
        if (!p1) q <= '0;
        else q <= {p13,p12,p5,p4};
    end
    assign #(T_PD) p2 = powered ? (q[0]) : 1'bx;
    assign #(T_PD) p7 = powered ? (q[1]) : 1'bx;
    assign #(T_PD) p10 = powered ? (q[2]) : 1'bx;
    assign #(T_PD) p15 = powered ? (q[3]) : 1'bx;
    assign #(T_PD) p3 = powered ? (~q[0]) : 1'bx;
    assign #(T_PD) p6 = powered ? (~q[1]) : 1'bx;
    assign #(T_PD) p11 = powered ? (~q[2]) : 1'bx;
    assign #(T_PD) p14 = powered ? (~q[3]) : 1'bx;

endmodule
`default_nettype wire
