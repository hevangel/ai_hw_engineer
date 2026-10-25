`timescale 1ns/1ps

// SN74LS181 4-bit arithmetic logic unit / function generator.
// Active-HIGH data convention; Cn, Cn+4, P, and G are active LOW.
module alu_74181 (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic [3:0] s,
    input  logic       m,
    input  logic       cn,
    output logic [3:0] f,
    output logic       cn4,
    output logic       a_eq_b,
    output logic       p_bar,
    output logic       g_bar
);

    // Datasheet bit terms. X is the active-HIGH propagate term and Y is the
    // active-HIGH generate term used by the internal carry-lookahead network.
    logic [3:0] x;
    logic [3:0] y;
    logic [3:0] carry;
    logic       carry4;

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            x[i] = a[i] | (b[i] & s[0]) | (~b[i] & s[1]);
            y[i] = (a[i] & ~b[i] & s[2]) | (a[i] & b[i] & s[3]);
        end
    end

    // Cn is active LOW. Logic mode suppresses every internal carry; arithmetic
    // mode inserts ~Cn and applies the four-bit lookahead recurrence.
    always_comb begin
        carry[0] = ~cn & ~m;
        carry[1] = (y[0] & ~m) | (x[0] & carry[0]);
        carry[2] = (y[1] & ~m) | (x[1] & carry[1]);
        carry[3] = (y[2] & ~m) | (x[2] & carry[2]);
        carry4   = (y[3] & ~m) | (x[3] & carry[3]);
    end

    // M supplies the logic-mode inversion shown by the active-HIGH table.
    always_comb begin
        f = x ^ y ^ carry ^ {4{m}};
    end

    // Original package outputs use active-LOW carry-lookahead polarity.
    always_comb begin
        cn4   = ~carry4;
        p_bar = ~(x[3] & x[2] & x[1] & x[0]);
        g_bar = ~(y[3] |
                  (x[3] & y[2]) |
                  (x[3] & x[2] & y[1]) |
                  (x[3] & x[2] & x[1] & y[0]));
        a_eq_b = &f;
    end

endmodule
