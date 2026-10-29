// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74408.md.
// ttl_74408 - 8-bit parity tree. y = ^data (odd parity).
module ttl_74408 (
    input  logic [7:0] data,
    output logic       parity
);
    assign parity = ^data;
endmodule
