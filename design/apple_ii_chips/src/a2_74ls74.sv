// Physical-pin functional model. See ../spec/spec.md for timing assumptions.
`timescale 1ns/1ps
`default_nettype none
module a2_74ls74 #(parameter integer T_PD = 0) (
    input tri p1, // ~{R}
    input tri p2, // D
    input tri p3, // C
    input tri p4, // ~{S}
    output tri p5, // Q
    output tri p6, // ~{Q}
    input tri p7, // GND
    output tri p8, // ~{Q}
    output tri p9, // Q
    input tri p10, // ~{S}
    input tri p11, // C
    input tri p12, // D
    input tri p13, // ~{R}
    input tri p14 // VCC
);
    logic powered;
    assign powered = (p14 === 1'b1 && p7 === 1'b0);
    // ASSUMPTION: ideal power and uniform optional output delay; no analog effects.

    logic q0, n0, previous_clock0;
    // Both edges of asynchronous controls matter when releasing the forbidden
    // clear+preset combination. This is a package simulation event model.
    always_ff @(posedge p3 or negedge p3 or posedge p1
                or negedge p1 or posedge p4 or negedge p4) begin
        if (!p1 && !p4) begin q0 <= 1; n0 <= 1; end
        else if (!p1) begin q0 <= 0; n0 <= 1; end
        else if (!p4) begin q0 <= 1; n0 <= 0; end
        else if (p3 === 1'b1 && previous_clock0 !== 1'b1) begin
            q0 <= p2; n0 <= ~p2;
        end else if (q0 === 1'b1 && n0 === 1'b1) begin
            // Simultaneous release of forbidden controls has no defined result.
            q0 <= 1'bx; n0 <= 1'bx;
        end
        previous_clock0 <= p3;
    end
    assign #(T_PD) p5 = powered ? (q0) : 1'bx;
    assign #(T_PD) p6 = powered ? (n0) : 1'bx;
    logic q1, n1, previous_clock1;
    // Both edges of asynchronous controls matter when releasing the forbidden
    // clear+preset combination. This is a package simulation event model.
    always_ff @(posedge p11 or negedge p11 or posedge p13
                or negedge p13 or posedge p10 or negedge p10) begin
        if (!p13 && !p10) begin q1 <= 1; n1 <= 1; end
        else if (!p13) begin q1 <= 0; n1 <= 1; end
        else if (!p10) begin q1 <= 1; n1 <= 0; end
        else if (p11 === 1'b1 && previous_clock1 !== 1'b1) begin
            q1 <= p12; n1 <= ~p12;
        end else if (q1 === 1'b1 && n1 === 1'b1) begin
            // Simultaneous release of forbidden controls has no defined result.
            q1 <= 1'bx; n1 <= 1'bx;
        end
        previous_clock1 <= p11;
    end
    assign #(T_PD) p9 = powered ? (q1) : 1'bx;
    assign #(T_PD) p8 = powered ? (n1) : 1'bx;

endmodule
`default_nettype wire
