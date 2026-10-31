// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x280 - 9-bit parity generator/checker.
module ttl_74x280 (
    input  logic [8:0] data,
    output logic       even_out,
    output logic       odd_out
);
    assign odd_out  =  ^data;
    assign even_out = ~^data;
endmodule
