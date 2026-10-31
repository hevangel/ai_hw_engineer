// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x125 - Quad bus buffer, negative enable, 3-state outputs.
// y[i] = oe_n[i] ? 0 : a[i]
module ttl_74x125 (
    input  logic [3:0] a,
    input  logic [3:0] oe_n,
    output logic [3:0] y,
    output logic [3:0] drive_en
);
    always_comb begin
        for (int i = 0; i < 4; i++) y[i] = oe_n[i] ? 1'b0 : a[i];
    end
    assign drive_en = ~oe_n;
endmodule
