// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x940.md.
// ttl_74x940 - Octal bus/line driver / line receiver, inverting (3-state).
// Logically a 74x240 (dual 4-bit inverting with active-low enables). The
// Schmitt-trigger inputs are an analog feature not modeled.
module ttl_74x940 (
    input  logic [7:0] a,
    input  logic       oe1_n, oe2_n,
    output logic [7:0] y
);
    assign y[3:0] = oe1_n ? 4'h0 : ~a[3:0];
    assign y[7:4] = oe2_n ? 4'h0 : ~a[7:4];
endmodule
