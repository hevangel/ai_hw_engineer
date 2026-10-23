// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// =============================================================================
// ttl_74x139 - Dual 2-to-4 line decoder/demultiplexer, active-low outputs
//
// Two independent decoders. Each has 2 select bits, one active-low enable,
// and 4 active-low outputs.
//
//   For decoder i in 0..1:
//     when g_n[i]=0:  y_n[i*4 + a[i]] = 0, others = 1
//     when g_n[i]=1:  all four y_n outputs = 1
// =============================================================================

module ttl_74x139 (
    input  logic [1:0] g_n,        // per-decoder enable, active low
    input  logic [3:0] a,          // packed: a[1:0] for dec0, a[3:2] for dec1
    output logic [7:0] y_n         // packed: y_n[3:0] for dec0, y_n[7:4] for dec1
);
    always_comb begin
        y_n = 8'hFF;
        if (!g_n[0]) y_n[{1'b0, a[1:0]}] = 1'b0;
        if (!g_n[1]) y_n[{1'b1, a[3:2]}] = 1'b0;
    end
endmodule
