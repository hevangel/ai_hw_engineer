// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x146 - 3-to-8 line decoder (variant of 74x138).
module ttl_74x146 (
    input  logic [2:0] a,
    input  logic       en_n,
    output logic [7:0] y_n
);
    always_comb begin
        y_n = 8'hFF;
        if (!en_n) y_n[a] = 1'b0;
    end
endmodule
