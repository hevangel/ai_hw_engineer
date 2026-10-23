`timescale 1ns/1ps
module tb_ttl_74x16622;
    logic [17:0] a_in, b_in, a_out, a_drive, b_drive;
    logic oeab_n, oeba_n, clkab, clkba;
    logic [1:0] ceab, ceba;

    ttl_74x16622 dut(.*);

    logic [17:0] pstate_ab, pstate_ba;
    logic [17:0] exp_ab, exp_ba;

    task automatic tick;
        clkab = 1'b1;
        clkba = 1'b1;
        #1;
        clkab = 1'b0;
        clkba = 1'b0;
        #1;
    endtask

    task automatic check_outputs(input logic en_ab, input logic en_ba);
        if (a_out !== (en_ba ? pstate_ba : '0))
            $fatal(1, "16622 A data mismatch: got %05x want %05x", a_out, pstate_ba);
        for (int k = 0; k < 18; k++)
            if (a_drive[k] !== en_ba)
                $fatal(1, "16622 A drive bit %0d mismatch", k);
        if (b_drive !== (en_ab ? ~pstate_ab : '0))
            $fatal(1, "16622 B sink mask mismatch: got %05x", b_drive);
    endtask

    initial begin
        oeab_n = 1'b0;
        oeba_n = 1'b0;
        clkab = 1'b0;
        clkba = 1'b0;
        ceab = 2'b00;
        ceba = 2'b00;
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
        check_outputs(1'b1, 1'b1);

        // Steady clock levels hold; input changes do not leak.
        a_in = 18'h0C3A5;
        b_in = 18'h13C5A;
        #1;
        check_outputs(1'b1, 1'b1);

        // CE high on one bank holds that bank only; the other bank captures.
        ceab = 2'b01;
        ceba = 2'b01;
        #1;
        tick();
        exp_ab = pstate_ab;
        exp_ba = pstate_ba;
        exp_ab[17:9] = a_in[17:9];
        exp_ba[17:9] = b_in[17:9];
        pstate_ab = exp_ab;
        pstate_ba = exp_ba;
        check_outputs(1'b1, 1'b1);

        ceab = 2'b10;
        ceba = 2'b10;
        a_in = 18'h2B64D;
        b_in = 18'h14C92;
        #1;
        tick();
        exp_ab = pstate_ab;
        exp_ba = pstate_ba;
        exp_ab[8:0] = a_in[8:0];
        exp_ba[8:0] = b_in[8:0];
        pstate_ab = exp_ab;
        pstate_ba = exp_ba;
        check_outputs(1'b1, 1'b1);

        // Both banks capture again with CE low everywhere.
        ceab = 2'b00;
        ceba = 2'b00;
        a_in = 18'h25255;
        b_in = 18'h0DAD2;
        #1;
        tick();
        pstate_ab = a_in;
        pstate_ba = b_in;
        check_outputs(1'b1, 1'b1);

        // Output enables isolate directions while storage keeps operating.
        oeab_n = 1'b1;
        #1;
        check_outputs(1'b0, 1'b1);
        oeab_n = 1'b0;
        oeba_n = 1'b1;
        #1;
        check_outputs(1'b1, 1'b0);
        oeba_n = 1'b0;
        #1;
        check_outputs(1'b1, 1'b1);

        $display("PASS: tb_ttl_74x16622");
        $finish;
    end
endmodule
