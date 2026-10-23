// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x80 - Gated full adder (1-bit).
// A = a1 & a2 (gated A), B = b1 & b2 (gated B), c_in_n active-low carry in.
// Outputs: sum, sum_n, c_out.
module ttl_74x80 (
    input  logic a1, a2,
    input  logic b1, b2,
    input  logic c_in_n,
    output logic sum,
    output logic sum_n,
    output logic c_out
);
    logic a, b, c_in;
    logic [1:0] r;
    assign a = a1 & a2;
    assign b = b1 & b2;
    assign c_in = ~c_in_n;
    assign r = a + b + c_in;
    assign sum   =  r[0];
    assign sum_n = ~r[0];
    assign c_out =  r[1];
endmodule
