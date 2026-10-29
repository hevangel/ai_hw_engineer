// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x251 - 8-to-1 mux with 3-state, complementary outputs.
module ttl_74x251 (
    input  logic       g_n,
    input  logic [2:0] s,
    input  logic [7:0] d,
    output logic       y,
    output logic       y_n,
    output logic  drive_en
);
    always_comb begin
        if (g_n) begin
            y   = 1'b0;
            y_n = 1'b0;        // 3-state in original; muxed-zero here
        end else begin
            y   = d[s];
            y_n = ~d[s];
        end
    end
    assign drive_en = ~g_n;
endmodule
