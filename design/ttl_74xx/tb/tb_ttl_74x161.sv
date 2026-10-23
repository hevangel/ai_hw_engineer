// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x161;
    logic clk, clr_n, load_n, enp, ent;
    logic [3:0] d, q;
    logic rco;

    ttl_74x161 dut (.clk(clk), .clr_n(clr_n), .load_n(load_n),
                    .enp(enp), .ent(ent), .d(d), .q(q), .rco(rco));

    task automatic tick; clk = 0; #1; clk = 1; #1; clk = 0; #1; endtask

    int errors;
    initial begin
        errors = 0;
        clk = 0; clr_n = 1; load_n = 1; enp = 1; ent = 1; d = 0; #1;
        // Async clear immediately
        clr_n = 0; #1;
        if (q !== 4'h0) errors++;
        clr_n = 1; #1;

        // Count up
        for (int i = 0; i < 17; i++) begin
            if (q !== i[3:0]) errors++;
            tick;
        end

        // Sync load
        load_n = 0; d = 4'hA; tick;
        if (q !== 4'hA) errors++;
        load_n = 1;

        // Async clear should work even with load asserted
        load_n = 0; d = 4'hC; clr_n = 0; #1;
        if (q !== 4'h0) errors++;
        clr_n = 1; load_n = 1; #1;

        // rco at q=F
        clr_n = 0; #1; clr_n = 1; #1; // start at 0
        load_n = 0; d = 4'hF; tick; load_n = 1;
        if (q !== 4'hF || rco !== 1'b1) errors++;
        ent = 0; #1;
        if (rco !== 1'b0) errors++;
        ent = 1; #1;

        if (errors != 0) $fatal(1, "tb_ttl_74x161: %0d errors", errors);
        $display("PASS: tb_ttl_74x161");
        $finish;
    end
endmodule
