`timescale 1ns/1ps
module tb_ttl_74x2107;
    logic en1;
    logic [1:0] bi_1_2;
    logic [1:0] ao_1_2_drive_low;
    logic en2;
    logic [1:0] bi_3_4;
    logic [1:0] ao_3_4_drive_low;
    logic bi_9;
    logic ao_9;
    logic [1:0] bi_5_6;
    logic [1:0] a_5_6_ext_drive;
    logic [1:0] a_5_6_ext_data;
    logic [1:0] a_5_6_drive_low;
    logic [1:0] a_5_6_bus;
    logic [1:0] bo_7_drive_low;
    logic ai_8;
    logic bo_8_drive_low;
    logic [1:0] ai_10;
    logic [1:0] bo_10_drive_low;
    logic bi_11;
    logic a_11_ext_drive;
    logic a_11_ext_data;
    logic a_11_drive_low;
    logic a_11_bus;
    logic bo_11_drive_low;
    logic [1:0] expected_bus;
    int code;
    int direct_code;
    int ai_code;
    int ext_drive_code;
    int ext_data_code;
    int bi_code;
    int en_code;
    int lane;

    ttl_74x2107 dut (.*);

    initial begin
        bi_5_6 = '0;
        a_5_6_ext_drive = '0;
        a_5_6_ext_data = '0;
        bi_11 = 1'b0;
        a_11_ext_drive = 1'b0;
        a_11_ext_data = 1'b0;
        for (direct_code = 0; direct_code < 16; direct_code = direct_code + 1) begin
            bi_1_2 = direct_code[1:0];
            bi_3_4 = direct_code[3:2];
            for (en_code = 0; en_code < 4; en_code = en_code + 1) begin
                en1 = en_code[0];
                en2 = en_code[1];
                #1;
                if (ao_1_2_drive_low !== ({2{en1}} & ~bi_1_2)
                    || ao_3_4_drive_low !== ({2{en2}} & ~bi_3_4))
                    $fatal(1, "open-drain AO enable table mismatch");
            end
        end
        for (code = 0; code < 2; code = code + 1) begin
            bi_9 = code[0];
            ai_8 = code[0];
            #1;
            if (ao_9 !== bi_9 || bo_8_drive_low !== ~ai_8)
                $fatal(1, "9AO or 8BO table mismatch");
        end
        for (ai_code = 0; ai_code < 4; ai_code = ai_code + 1) begin
            ai_10 = ai_code[1:0];
            for (bi_code = 0; bi_code < 2; bi_code = bi_code + 1) begin
                bi_9 = bi_code[0];
                #1;
                if (bo_10_drive_low !== ~(ai_10 & {2{bi_9}}))
                    $fatal(1, "10AI/9BI gate mismatch");
            end
        end
        for (en_code = 0; en_code < 2; en_code = en_code + 1) begin
            en2 = en_code[0];
            for (bi_code = 0; bi_code < 4; bi_code = bi_code + 1) begin
                bi_5_6 = bi_code[1:0];
                for (ext_drive_code = 0; ext_drive_code < 4; ext_drive_code = ext_drive_code + 1) begin
                    a_5_6_ext_drive = ext_drive_code[1:0];
                    for (ext_data_code = 0; ext_data_code < 4; ext_data_code = ext_data_code + 1) begin
                        a_5_6_ext_data = ext_data_code[1:0];
                        #1;
                        for (lane = 0; lane < 2; lane = lane + 1) begin
                            if (en2 && !bi_5_6[lane])
                                expected_bus[lane] = 1'b0;
                            else if (a_5_6_ext_drive[lane])
                                expected_bus[lane] = a_5_6_ext_data[lane];
                            else
                                expected_bus[lane] = 1'b1;
                        end
                        if (a_5_6_drive_low !== ({2{en2}} & ~bi_5_6)
                            || a_5_6_bus !== expected_bus
                            || bo_7_drive_low !== (bi_5_6 & ~expected_bus))
                            $fatal(1, "EN2/5A/6A/7BO interaction mismatch");
                    end
                end
            end
        end
        for (bi_code = 0; bi_code < 2; bi_code = bi_code + 1) begin
            bi_11 = bi_code[0];
            for (ext_drive_code = 0; ext_drive_code < 2; ext_drive_code = ext_drive_code + 1) begin
                a_11_ext_drive = ext_drive_code[0];
                for (ext_data_code = 0; ext_data_code < 2; ext_data_code = ext_data_code + 1) begin
                    a_11_ext_data = ext_data_code[0];
                    #1;
                    if (bi_11)
                        expected_bus[0] = 1'b0;
                    else if (a_11_ext_drive)
                        expected_bus[0] = a_11_ext_data;
                    else
                        expected_bus[0] = 1'b1;
                    if (a_11_drive_low !== bi_11 || a_11_bus !== expected_bus[0]
                        || bo_11_drive_low !== expected_bus[0])
                        $fatal(1, "11A/11BI/11BO interaction mismatch");
                end
            end
        end
        $display("PASS: tb_ttl_74x2107 SN74GTL2107 function tables and OD enable interactions");
        $finish;
    end
endmodule
