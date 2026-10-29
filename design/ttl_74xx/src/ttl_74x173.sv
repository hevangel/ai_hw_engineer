// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x173 - Quad D FF, shared clock, async clear, with enable, Q/Q_n.
// When enable g_n=0, load d; else hold.
module ttl_74x173 (
    input  logic       clk,
    input  logic       clr,        // async clear, active high
    input  logic [1:0] g_n,        // 2 active-low enables; both must be low to load
    input  logic [3:0] d,
    input  logic       oe_n,       // active-low output enable (3-state in original)
    output logic [3:0] q,
    output logic [3:0] drive_en
);
    logic [3:0] q_reg;
    always_ff @(posedge clk or posedge clr) begin
        if (clr)                        q_reg <= 4'h0;
        else if (!g_n[0] && !g_n[1])    q_reg <= d;
    end
    assign q = oe_n ? 4'h0 : q_reg;
    assign drive_en = '1 & {4{~oe_n}};
endmodule
