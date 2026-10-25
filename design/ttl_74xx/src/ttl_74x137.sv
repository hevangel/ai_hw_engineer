// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x137 - 3-to-8 decoder with address latch, inverting outputs.
// Address is latched (transparent when le=1, holds when le=0).
module ttl_74x137 (
    input  logic       le,        // address latch enable, transparent when 1
    input  logic       en_n,      // chip enable, active low
    input  logic [2:0] a,
    output logic [7:0] y_n
);
    logic [2:0] addr_latch;

    always_latch begin
        if (le) addr_latch = a;
    end

    always_comb begin
        y_n = 8'hFF;
        if (!en_n) y_n[addr_latch] = 1'b0;
    end
endmodule
