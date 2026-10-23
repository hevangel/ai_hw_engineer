// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_ttl_74x758;
    logic g_ab_n, g_ba;
    logic [3:0] a_in, b_in;
    logic [3:0] a_out, b_out;
    logic a_drive, b_drive;

    ttl_74x758 dut (.*);

    int unsigned pattern;
    initial begin
        g_ab_n = 1'b1;
        g_ba = 1'b0;
        a_in = 4'b0000;
        b_in = 4'b0000;
        #1;
        if (a_drive !== 1'b0 || b_drive !== 1'b0 ||
            a_out !== 4'b0000 || b_out !== 4'b0000) begin
            $fatal(1, "isolation must release both ports");
        end

        for (pattern = 0; pattern < 16; pattern++) begin
            // A-to-B transfer follows A while selected; the 758 complements it.
            g_ab_n = 1'b0;
            g_ba = 1'b0;
            a_in = pattern[3:0];
            b_in = ~pattern[3:0];
            #1;
            if (a_drive !== 1'b0 || b_drive !== 1'b1 ||
                a_out !== 4'b0000 || b_out !== ~a_in) begin
                $fatal(1, "A-to-B mismatch for A=%h", a_in);
            end
            a_in = ~pattern[3:0];
            #1;
            if (b_out !== ~a_in) $fatal(1, "A-to-B was not transparent");

            // Enter feedback from the established transfer, without external contention.
            a_in = pattern[3:0];
            #1;
            g_ba = 1'b1;
            #1;
            a_in = ~pattern[3:0];
            b_in = pattern[3:0];
            #1;
            if (a_drive !== 1'b1 || b_drive !== 1'b1 ||
                a_out !== pattern[3:0] || b_out !== ~pattern[3:0]) begin
                $fatal(1, "A-to-B latch mismatch for A=%h", pattern[3:0]);
            end

            // Isolation releases both outputs. It does not add a clock/reset.
            g_ab_n = 1'b1;
            g_ba = 1'b0;
            #1;
            if (a_drive !== 1'b0 || b_drive !== 1'b0 ||
                a_out !== 4'b0000 || b_out !== 4'b0000) begin
                $fatal(1, "isolation mismatch after latch");
            end

            // B-to-A transfer follows B and is also inverting.
            g_ab_n = 1'b1;
            g_ba = 1'b1;
            b_in = pattern[3:0];
            #1;
            if (a_drive !== 1'b1 || b_drive !== 1'b0 ||
                a_out !== ~b_in || b_out !== 4'b0000) begin
                $fatal(1, "B-to-A mismatch for B=%h", b_in);
            end
            b_in = ~pattern[3:0];
            #1;
            if (a_out !== ~b_in) $fatal(1, "B-to-A was not transparent");

            // Capture the final B-to-A value and prove feedback-mode hold.
            b_in = pattern[3:0];
            #1;
            g_ab_n = 1'b0;
            #1;
            a_in = pattern[3:0];
            b_in = ~pattern[3:0];
            #1;
            if (a_drive !== 1'b1 || b_drive !== 1'b1 ||
                a_out !== ~pattern[3:0] || b_out !== pattern[3:0]) begin
                $fatal(1, "B-to-A latch mismatch for B=%h", pattern[3:0]);
            end
        end

        $display("PASS: tb_ttl_74x758");
        $finish;
    end
endmodule
