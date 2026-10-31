`timescale 1ns/1ps
module tb_ttl_74x16241;
    logic [15:0] a_in;
    logic oe1_n, oe2, oe3, oe4_n;
    logic [15:0] y_out;
    logic [3:0] y_drive;
    logic [15:0] expected_out;
    logic [3:0] expected_drive;
    int unsigned controls;
    int unsigned pattern;

    ttl_74x16241 dut(.*);

    initial begin
        for (controls = 0; controls < 16; controls++) begin
            oe1_n = controls[0];
            oe2 = controls[1];
            oe3 = controls[2];
            oe4_n = controls[3];

            for (pattern = 0; pattern < 256; pattern++) begin
                a_in = {8'(pattern), 8'(pattern ^ 8'hA5)};
                expected_drive = {~oe4_n, oe3, oe2, ~oe1_n};
                expected_out = 16'h0000;
                if (expected_drive[0]) expected_out[3:0] = a_in[3:0];
                if (expected_drive[1]) expected_out[7:4] = a_in[7:4];
                if (expected_drive[2]) expected_out[11:8] = a_in[11:8];
                if (expected_drive[3]) expected_out[15:12] = a_in[15:12];
                #1;
                if (y_drive !== expected_drive || y_out !== expected_out)
                    $fatal(1, "16241 mismatch controls=%0d pattern=%0d", controls, pattern);
            end
        end

        $display("PASS: tb_ttl_74x16241");
        $finish;
    end
endmodule
