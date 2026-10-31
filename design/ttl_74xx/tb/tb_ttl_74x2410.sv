`timescale 1ns/1ps
module tb_ttl_74x2410;
    logic [10:0] a, y, drive;
    logic g1_n, g2_n;
    logic [10:0] expected_y, expected_drive;
    logic enabled;
    ttl_74x2410 dut(.*);

    initial begin
        for (int controls = 0; controls < 4; controls++) begin
            g1_n = 1'(controls & 1);
            g2_n = 1'((controls >> 1) & 1);
            for (int data_value = 0; data_value < 2048; data_value++) begin
                a = 11'(data_value);
                #1;
                enabled = (g1_n == 1'b0) && (g2_n == 1'b0);
                expected_drive = enabled ? 11'h7ff : 11'h000;
                expected_y = enabled ? a : 11'h000;
                if (drive !== expected_drive || y !== expected_y) begin
                    $fatal(1, "G1_N=%b G2_N=%b A=%h Y=%h DRIVE=%h",
                           g1_n, g2_n, a, y, drive);
                end
            end
        end
        $display("PASS: tb_ttl_74x2410");
        $finish;
    end
endmodule
