`timescale 1ns/1ps
module tb_ttl_74x658;
    logic gba_n, gab, api, bpi;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_drive, b_drive, apo, bpo, apo_drive, bpo_drive;
    logic exp_a_drive, exp_b_drive, exp_apo, exp_bpo, exp_apo_drive, exp_bpo_drive;
    logic [7:0] exp_a, exp_b;
    int errors, value, mode, bit_index, count_a, count_b;

    ttl_74x658 dut (.*);

    initial begin
        errors = 0;
        for (value = 0; value < 256; value = value + 1) begin
            a_in = value[7:0];
            b_in = (value * 73 + 19) & 255;
            api = value[0];
            bpi = value[1];
            for (mode = 0; mode < 4; mode = mode + 1) begin
                gba_n = mode[1];
                gab = mode[0];
                #1;
                exp_a_drive = !gba_n;
                exp_b_drive = gab;
                exp_apo_drive = gab;
                exp_bpo_drive = !gba_n;
                exp_a = exp_a_drive ? ~b_in : 8'h00;
                exp_b = exp_b_drive ? ~a_in : 8'h00;
                count_a = api;
                count_b = bpi;
                for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                    count_a = count_a + a_in[bit_index];
                    count_b = count_b + b_in[bit_index];
                end
                exp_apo = exp_apo_drive && ((count_a % 2) == 0);
                exp_bpo = exp_bpo_drive && ((count_b % 2) == 0);
                if (a_drive !== exp_a_drive || b_drive !== exp_b_drive ||
                    apo_drive !== exp_apo_drive || bpo_drive !== exp_bpo_drive ||
                    a_out !== exp_a || b_out !== exp_b || apo !== exp_apo || bpo !== exp_bpo)
                    errors = errors + 1;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x658: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x658");
        $finish;
    end
endmodule
