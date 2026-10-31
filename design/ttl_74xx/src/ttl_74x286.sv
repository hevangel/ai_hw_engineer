// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x286 - 9-bit parity generator/checker with bus parity I/O.
module ttl_74x286 (
    input  logic [8:0] data,
    input  logic       oe_n,
    output logic       even_out,
    output logic       odd_out
);
    logic odd_int;
    assign odd_int = ^data;
    assign odd_out  = oe_n ? 1'b0 :  odd_int;
    assign even_out = oe_n ? 1'b0 : ~odd_int;
endmodule
