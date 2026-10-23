// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x237 - 3-to-8 decoder with address latch, active-high outputs.
module ttl_74x237 (
    input  logic       le,
    input  logic       en_n,
    input  logic [2:0] a,
    output logic [7:0] y
);
    logic [2:0] addr_latch;
    always_latch begin
        if (le) addr_latch = a;
    end
    always_comb begin
        y = 8'h00;
        if (!en_n) y[addr_latch] = 1'b1;
    end
endmodule
