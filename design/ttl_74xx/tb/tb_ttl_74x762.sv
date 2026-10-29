// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_ttl_74x762;
    logic g1_n, g2_n;
    logic [3:0] a1, a2;
    logic [3:0] y1, y2;
    logic y1_drive, y2_drive;

    ttl_74x762 dut (.*);

    int unsigned pattern;
    int unsigned enables;
    initial begin
        for (enables = 0; enables < 4; enables++) begin
            g1_n = enables[1];
            g2_n = enables[0];
            for (pattern = 0; pattern < 16; pattern++) begin
                a1 = pattern[3:0];
                a2 = (pattern ^ 4'hA);
                #1;
                if (y1_drive !== !g1_n || y2_drive !== !g2_n) begin
                    $fatal(1, "drive flags mismatch for enables=%b", enables[1:0]);
                end
                if (y1 !== (g1_n ? 4'b0000 : ~a1)) begin
                    $fatal(1, "bank 1 mismatch for enable=%b input=%h", g1_n, a1);
                end
                if (y2 !== (g2_n ? 4'b0000 : a2)) begin
                    $fatal(1, "bank 2 mismatch for enable=%b input=%h", g2_n, a2);
                end
            end
        end

        $display("PASS: tb_ttl_74x762");
        $finish;
    end
endmodule
