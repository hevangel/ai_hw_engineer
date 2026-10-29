`timescale 1ns/1ps
module tb_ttl_74x16616;
    logic [16:0] a_in, b_in, a_out, a_drive, b_drive;
    logic oeab_n, oeba_n, ceab_n, ceba_n, leab, leba, clkab, clkba;
    logic clkin, clkout_sink;

    ttl_74x16616 dut(.*);

    logic [16:0] pstate_ab, pstate_ba;

    task automatic check_a(input logic [16:0] exp_data, input logic exp_drive);
        if (a_out !== (exp_drive ? exp_data : '0))
            $fatal(1, "16616 A data mismatch: got %05x", a_out);
        for (int k = 0; k < 17; k++)
            if (a_drive[k] !== exp_drive)
                $fatal(1, "16616 A drive bit %0d mismatch", k);
    endtask

    initial begin
        oeab_n = 1'b0;
        oeba_n = 1'b0;
        ceab_n = 1'b0;
        ceba_n = 1'b0;
        leab = 1'b0;
        leba = 1'b0;
        clkab = 1'b0;
        clkba = 1'b0;
        clkin = 1'b0;
        a_in = '0;
        b_in = '0;
        #1;

        // CLKOUT open-drain copy: sinks only while CLKAB high and OEAB low.
        clkab = 1'b1;
        #1;
        if (clkout_sink !== 1'b1) $fatal(1, "16616 CLKOUT must sink with CLKAB high");
        clkab = 1'b0;
        #1;
        if (clkout_sink !== 1'b0) $fatal(1, "16616 CLKOUT must release with CLKAB low");
        oeab_n = 1'b1;
        clkab = 1'b1;
        #1;
        if (clkout_sink !== 1'b0) $fatal(1, "16616 CLKOUT must release when OEAB high");
        oeab_n = 1'b0;
        clkab = 1'b0;
        #1;

        // True transparent mode follows each bus.
        leab = 1'b1;
        leba = 1'b1;
        a_in = 17'h155AA;
        b_in = 17'h0A555;
        #1;
        if (b_drive !== ~a_in) $fatal(1, "16616 transparent A-to-B sink mask");
        check_a(b_in, 1'b1);

        // Output enables isolate each direction.
        oeab_n = 1'b1;
        #1;
        if (b_drive !== '0 || clkout_sink !== 1'b0) $fatal(1, "16616 B isolation");
        check_a(b_in, 1'b1);
        oeab_n = 1'b0;
        oeba_n = 1'b1;
        #1;
        if (b_drive !== ~a_in) $fatal(1, "16616 B re-enabled");
        check_a(b_in, 1'b0);
        oeba_n = 1'b0;

        // LE fall captures the last transparent value; later inputs hold.
        a_in = 17'h0C3A5;
        b_in = 17'h13C5A;
        #1;
        pstate_ab = a_in;
        pstate_ba = b_in;
        leab = 1'b0;
        leba = 1'b0;
        #1;
        a_in = 17'h155AA;
        b_in = 17'h0A555;
        #1;
        if (b_drive !== ~pstate_ab) $fatal(1, "16616 stored A-to-B");
        check_a(pstate_ba, 1'b1);

        // CE high (clock-enable released) inhibits rising-edge capture.
        ceab_n = 1'b1;
        ceba_n = 1'b1;
        clkab = 1'b1;
        clkba = 1'b1;
        #1;
        clkab = 1'b0;
        clkba = 1'b0;
        #1;
        if (b_drive !== ~pstate_ab) $fatal(1, "16616 clock inhibit A-to-B");
        check_a(pstate_ba, 1'b1);

        // CE low permits rising-edge capture; falling edges and levels hold.
        ceab_n = 1'b0;
        ceba_n = 1'b0;
        a_in = 17'h0C3A5;
        b_in = 17'h13C5A;
        #1;
        clkab = 1'b1;
        clkba = 1'b1;
        #1;
        clkab = 1'b0;
        clkba = 1'b0;
        #1;
        pstate_ab = a_in;
        pstate_ba = b_in;
        if (b_drive !== ~pstate_ab) $fatal(1, "16616 clocked capture A-to-B");
        check_a(pstate_ba, 1'b1);
        clkab = 1'b1;
        clkba = 1'b1;
        #1;
        clkab = 1'b0;
        clkba = 1'b0;
        #1;
        if (b_drive !== ~pstate_ab) $fatal(1, "16616 falling edge must hold");
        check_a(pstate_ba, 1'b1);
        a_in = 17'h155AA;
        b_in = 17'h0A555;
        #1;
        if (b_drive !== ~pstate_ab) $fatal(1, "16616 falling edge must hold");
        check_a(pstate_ba, 1'b1);

        // CLKIN is an observation input; it must not disturb the data paths.
        clkin = 1'b1;
        #1;
        if (b_drive !== ~pstate_ab) $fatal(1, "16616 CLKIN observation only");
        check_a(pstate_ba, 1'b1);

        $display("PASS: tb_ttl_74x16616");
        $finish;
    end
endmodule
