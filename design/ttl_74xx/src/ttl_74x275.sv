// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x275 - 7-bit slice Wallace tree (carry-save adder of 7 numbers).
// In a Wallace tree, 7 single-bit inputs sum to a 3-bit count of '1's.
// This is the "compressor" view used in fast multiplier trees.
module ttl_74x275 (
    input  logic [6:0] x,
    output logic [2:0] count   // population count of x
);
    always_comb begin
        count = 3'd0;
        for (int i = 0; i < 7; i++) count += 3'(x[i]);
    end
endmodule
