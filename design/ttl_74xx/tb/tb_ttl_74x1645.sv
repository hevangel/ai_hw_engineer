`timescale 1ns/1ps
module tb_ttl_74x1645;
    logic [15:0] a_in, b_in, a_out, a_drive, b_drive;
    logic oe1, dir1, oe2, dir2;

    ttl_74x1645 dut(.*);

    logic [15:0] exp_a_out, exp_a_drive, exp_b_drive;

    always_comb begin
        exp_a_out = '0;
        exp_a_drive = '0;
        exp_b_drive = '0;
        if (!oe1) begin
            if (dir1) exp_b_drive[7:0] = ~a_in[7:0];
            else begin exp_a_drive[7:0] = '1; exp_a_out[7:0] = b_in[7:0]; end
        end
        if (!oe2) begin
            if (dir2) exp_b_drive[15:8] = ~a_in[15:8];
            else begin exp_a_drive[15:8] = '1; exp_a_out[15:8] = b_in[15:8]; end
        end
    end

    int unsigned controls;
    int unsigned pattern;

    initial begin
        for (controls = 0; controls < 16; controls++) begin
            oe1 = controls[0];
            dir1 = controls[1];
            oe2 = controls[2];
            dir2 = controls[3];
            for (pattern = 0; pattern < 8; pattern++) begin
                a_in = {{8{pattern[2]}}, pattern[2:0], 5'(pattern)};
                b_in = {{8{!pattern[2]}}, 3'(pattern), 5'(pattern)};
                #1;
                if (a_out !== exp_a_out || a_drive !== exp_a_drive ||
                    b_drive !== exp_b_drive)
                    $fatal(1, "ttl_74x1645 mismatch controls=%0d pattern=%0d",
                           controls, pattern);
            end
        end
        $display("PASS: tb_ttl_74x1645");
        $finish;
    end
endmodule
