// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x182 - Look-ahead carry generator (for cascading 74181s).
// Computes carry signals: Cn+x, Cn+y, Cn+z and group P, G outputs.
// Inputs: Cn (carry into low group), P[3:0], G[3:0] from four 74181s.
// Outputs based on standard CLA equations.
module ttl_74x182 (
    input  logic       cn,
    input  logic [3:0] p_n,    // propagate (active low)
    input  logic [3:0] g_n,    // generate (active low)
    output logic       cn_p_x,
    output logic       cn_p_y,
    output logic       cn_p_z,
    output logic       p_grp_n,
    output logic       g_grp_n
);
    logic [3:0] p, g;
    assign p = ~p_n;
    assign g = ~g_n;

    assign cn_p_x = g[0] | (p[0] & cn);
    assign cn_p_y = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cn);
    assign cn_p_z = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cn);
    assign p_grp_n = ~(p[3] & p[2] & p[1] & p[0]);
    assign g_grp_n = ~(g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0]));
endmodule
