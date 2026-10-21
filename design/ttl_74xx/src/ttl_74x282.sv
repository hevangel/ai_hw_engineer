// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv and provenance.json.
// ttl_74x282 - Look-ahead carry generator with selectable carry inputs.
// Like 74x182 with a register-style carry input select.
module ttl_74x282 (
    input  logic       cn,
    input  logic [3:0] p_n,
    input  logic [3:0] g_n,
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
