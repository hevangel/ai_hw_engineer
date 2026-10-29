// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x282;
    logic cn;
    logic [3:0] p_n, g_n;
    logic cn_p_x, cn_p_y, cn_p_z, p_grp_n, g_grp_n;
    ttl_74x282 dut(.cn(cn), .p_n(p_n), .g_n(g_n), .cn_p_x(cn_p_x), .cn_p_y(cn_p_y), .cn_p_z(cn_p_z), .p_grp_n(p_grp_n), .g_grp_n(g_grp_n));
    int errors;
    initial begin
        errors = 0;
        cn=1; p_n=4'h0; g_n=4'hF; #1;
        if (cn_p_x !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x282: %0d errors", errors);
        $display("PASS: tb_ttl_74x282");
        $finish;
    end
endmodule
