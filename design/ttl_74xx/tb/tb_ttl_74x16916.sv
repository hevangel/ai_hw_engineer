`timescale 1ns/1ps
module tb_ttl_74x16916;
    logic [16:0] a_in, b_in, a_out;
    logic [16:0] a_drive, b_drive;
    logic oeab_n, oeba_n, ceab, ceba, leab, leba, clkab, clkba;

    ttl_74x16916 dut(.*);

    logic [16:0] pstate_ab, pstate_ba;

    task automatic tick_clkab;
        clkab = 1'b1;
        #1;
        clkab = 1'b0;
        #1;
    endtask

    task automatic tick_clkba;
        clkba = 1'b1;
        #1;
        clkba = 1'b0;
        #1;
    endtask

    task automatic check_ab(input logic [16:0] exp_sink);
        if (b_drive !== exp_sink)
            $fatal(1, "ttl_74x16916 B sink mask mismatch: got %05x want %05x", b_drive, exp_sink);
    endtask

    task automatic check_a(input logic [16:0] exp_data, input logic exp_drive);
        if (a_out !== (exp_drive ? exp_data : '0))
            $fatal(1, "ttl_74x16916 A data mismatch: got %05x", a_out);
        for (int k = 0; k < 17; k++)
            if (a_drive[k] !== exp_drive)
                $fatal(1, "ttl_74x16916 A drive bit %0d mismatch", k);
    endtask

    initial begin
        oeab_n = 1'b0;
        oeba_n = 1'b0;
        ceab = 1'b0;
        ceba = 1'b0;
        leab = 1'b0;
        leba = 1'b0;
        clkab = 1'b0;
        clkba = 1'b0;
        a_in = '0;
        b_in = '0;
        #1;

        // True transparent mode follows each bus with independent enables.
        leab = 1'b1;
        leba = 1'b1;
        a_in = {8'h25, 9'h155};
        b_in = {8'h5A, 9'h0AA};
        #1;
        check_ab(~a_in);
        check_a(b_in, 1'b1);

        // Output enables isolate each direction without disturbing storage.
        oeab_n = 1'b1;
        #1;
        check_ab('0);
        check_a(b_in, 1'b1);
        oeab_n = 1'b0;
        oeba_n = 1'b1;
        #1;
        check_ab(~a_in);
        check_a(b_in, 1'b0);
        oeba_n = 1'b0;

        // LE fall captures the last transparent value; later input changes hold.
        a_in = {8'hC3, 9'h155};
        b_in = {8'h96, 9'h0A5};
        #1;
        pstate_ab = a_in;
        pstate_ba = b_in;
        leab = 1'b0;
        leba = 1'b0;
        #1;
        a_in = {8'h25, 9'h155};
        b_in = {8'h5A, 9'h0AA};
        #1;
        check_ab(~pstate_ab);
        check_a(pstate_ba, 1'b1);

        // Steady clock levels hold; CE high inhibits capture on a clock edge.
        ceab = 1'b1;
        ceba = 1'b1;
        tick_clkab();
        tick_clkba();
        check_ab(~pstate_ab);
        check_a(pstate_ba, 1'b1);

        // CE low permits rising-edge capture; falling edges and levels hold.
        ceab = 1'b0;
        ceba = 1'b0;
        a_in = {8'hC3, 9'h155};
        b_in = {8'h96, 9'h0A5};
        #1;
        tick_clkab();
        tick_clkba();
        pstate_ab = a_in;
        pstate_ba = b_in;
        check_ab(~pstate_ab);
        check_a(pstate_ba, 1'b1);
        clkab = 1'b1;
        clkba = 1'b1;
        #1;
        clkab = 1'b0;
        clkba = 1'b0;
        #1;
        check_ab(~pstate_ab);
        check_a(pstate_ba, 1'b1);
        a_in = {8'h25, 9'h155};
        b_in = {8'h5A, 9'h0AA};
        #1;
        check_ab(~pstate_ab);
        check_a(pstate_ba, 1'b1);

        // Latched storage with CE low: re-transparentize, drop LE at level low.
        leab = 1'b1;
        leba = 1'b1;
        #1;
        a_in = {8'hC3, 9'h155};
        b_in = {8'h96, 9'h0A5};
        #1;
        pstate_ab = a_in;
        pstate_ba = b_in;
        leab = 1'b0;
        leba = 1'b0;
        #1;
        check_ab(~pstate_ab);
        check_a(pstate_ba, 1'b1);

        $display("PASS: tb_ttl_74x16916");
        $finish;
    end
endmodule
