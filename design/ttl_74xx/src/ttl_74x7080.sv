// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x7080.md.
// ttl_74x7080 - 16-bit parity generator / checker.
// Generates odd parity for the 16 data bits and the existing parity_in.
//   parity_out = ~(^{data, parity_in})
// even_n = parity_out, odd = ~parity_out.
module ttl_74x7080 (
    input  logic [15:0] d,
    input  logic        parity_in,
    output logic        sum_even,
    output logic        sum_odd
);
    wire xor_all = ^{d, parity_in};
    assign sum_even = ~xor_all;
    assign sum_odd  =  xor_all;
endmodule
