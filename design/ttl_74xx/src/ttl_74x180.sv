// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x180 - 9-bit (8 data + 1 even-control) parity generator/checker.
// Inputs: 8 data bits + even_in + odd_in (data control)
// Outputs: even_out = (even_in & XOR-of-data) | (odd_in & ~XOR-of-data)
//          odd_out  = (odd_in  & XOR-of-data) | (even_in & ~XOR-of-data)
// Simplified: when even_in=1, odd_in=0: parity = ^data; outputs as described.
module ttl_74x180 (
    input  logic [7:0] data,
    input  logic       even_in,
    input  logic       odd_in,
    output logic       even_out,
    output logic       odd_out
);
    logic data_xor;
    assign data_xor = ^data;
    assign even_out = (even_in & ~data_xor) | (odd_in & data_xor);
    assign odd_out  = (even_in &  data_xor) | (odd_in & ~data_xor);
endmodule
