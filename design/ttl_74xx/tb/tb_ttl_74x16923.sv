`timescale 1ns/1ps
module tb_ttl_74x16923;
    logic [17:0] a_in, b_in, a_out, b_drive;
    logic [1:0] oeab_n, oeba_n, a_drive;
    logic ceab_n, ceba_n, clkab, clkba;

    ttl_74x16923 dut(.*);

    logic [17:0] pstate_ab, pstate_ba;

    task automatic tick;
        clkab = 1'b1;
        clkba = 1'b1;
        #1;
        clkab = 1'b0;
        clkba = 1'b0;
        #1;
    endtask

    task automatic check_outputs(input logic [1:0] en_ab, input logic [1:0] en_ba);
        for (int bank = 0; bank < 2; bank++) begin
            if (a_out[bank*9 +: 9] !== (en_ba[bank] ? pstate_ba[bank*9 +: 9] : '0))
                $fatal(1, "16923 bank %0d A data mismatch", bank);
            if (a_drive[bank] !== en_ba[bank])
                $fatal(1, "16923 bank %0d A drive mismatch", bank);
            if (b_drive[bank*9 +: 9] !==
                (en_ab[bank] ? ~pstate_ab[bank*9 +: 9] : '0))
                $fatal(1, "16923 bank %0d B sink mismatch got %03x want %03x (oeab_n=%b)",
                       bank, b_drive[bank*9 +: 9],
                       en_ab[bank] ? ~pstate_ab[bank*9 +: 9] : '0, oeab_n);
        end
    endtask

    initial begin
        oeab_n = 2'b00;
        oeba_n = 2'b00;
        ceab_n = 1'b0;
        ceba_n = 1'b0;
        clkab = 1'b0;
        clkba = 1'b0;
        a_in = '0;
        b_in = '0;
        #1;

        // Rising edge captures both banks while CE is low.
        a_in = 18'h155AA;
        b_in = 18'h0A555;
        #1;
        tick();
        pstate_ab = a_in;
        pstate_ba = b_in;
        check_outputs(2'b11, 2'b11);

        // Steady clock levels hold; input changes do not leak.
        a_in = 18'h0C3A5;
        b_in = 18'h13C5A;
        #1;
        check_outputs(2'b11, 2'b11);

        // CE high inhibits both banks; outputs stay driven with stored data.
        ceab_n = 1'b1;
        ceba_n = 1'b1;
        a_in = 18'h3FFFF;
        b_in = 18'h00000;
        #1;
        tick();
        check_outputs(2'b11, 2'b11);

        // Common CE releases again and both banks capture.
        ceab_n = 1'b0;
        ceba_n = 1'b0;
        a_in = 18'h25255;
        b_in = 18'h0DAD2;
        #1;
        tick();
        pstate_ab = a_in;
        pstate_ba = b_in;
        check_outputs(2'b11, 2'b11);

        // Per-bank output enables isolate each 9-bit bank independently.
        oeab_n = 2'b01;
        oeba_n = 2'b10;
        #1;
        check_outputs(2'b10, 2'b01);
        oeab_n = 2'b10;
        oeba_n = 2'b01;
        #1;
        check_outputs(2'b01, 2'b10);
        oeab_n = 2'b11;
        oeba_n = 2'b11;
        #1;
        check_outputs(2'b00, 2'b00);
        oeab_n = 2'b00;
        oeba_n = 2'b00;
        #1;
        check_outputs(2'b11, 2'b11);

        $display("PASS: tb_ttl_74x16923");
        $finish;
    end
endmodule
