// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x278 - 4-bit cascadeable priority register, latched data inputs.
// 4 latched data inputs with priority encoding. Output is the highest-priority asserted input.
module ttl_74x278 (
    input  logic       le,         // latch enable
    input  logic [3:0] d,
    input  logic       cin_n,      // cascade input (active low)
    output logic [3:0] q,
    output logic       cout_n
);
    logic [3:0] latch_d;
    always_latch begin
        if (le) latch_d = d;
    end
    // Priority output: the highest set bit, others 0
    always_comb begin
        q = 4'h0;
        if (!cin_n) begin
            if      (latch_d[3]) q[3] = 1'b1;
            else if (latch_d[2]) q[2] = 1'b1;
            else if (latch_d[1]) q[1] = 1'b1;
            else if (latch_d[0]) q[0] = 1'b1;
        end
    end
    assign cout_n = ~(cin_n == 0 && latch_d != 4'h0);
endmodule
