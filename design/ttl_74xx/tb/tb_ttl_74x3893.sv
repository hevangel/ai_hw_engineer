`timescale 1ns/1ps
module tb_ttl_74x3893;
    logic       de, re_n;
    logic [3:0] d_in, io_in;
    logic [3:0] io_out, io_drive, r_out;
    logic       r_drive;
    logic [3:0] exp_io, exp_r;

    ttl_74x3893 dut(.*);

    initial begin
        // Exhaustive: both enables (4) x all data words (16) x all resolved
        // bus levels (16). Checks the NAND-with-DE open-collector driver and
        // the inverting RE-gated receivers across every function-table row.
        for (int e = 0; e < 4; e++) begin
            de = e[1]; re_n = e[0];
            for (int dv = 0; dv < 16; dv++) begin
                d_in = dv[3:0];
                for (int iv = 0; iv < 16; iv++) begin
                    io_in = iv[3:0];
                    #1;
                    exp_io = de ? d_in : 4'h0;      // NAND(D,DE): sink iff 1
                    exp_r = re_n ? 4'h0 : ~io_in;   // inverting receivers
                    if (io_drive !== exp_io || io_out !== 4'h0 ||
                        r_out !== exp_r || r_drive !== !re_n)
                        $fatal(1, "3893 sweep de=%0d re_n=%0d d=%0d io=%0d",
                               de, re_n, d_in, io_in);
                end
            end
        end

        // Spot-check the operating modes by name, including the quirk that a
        // transmitter keeps driving with its own receivers three-stated.
        de = 1'b1; re_n = 1'b0; d_in = 4'h5; io_in = 4'hA;
        #1;
        if (io_drive !== 4'h5 || r_out !== 4'h5 || r_drive !== 1'b1)
            $fatal(1, "3893 Transmit to Bus with receivers on");
        re_n = 1'b1;
        #1;
        if (io_drive !== 4'h5 || r_out !== 4'h0 || r_drive !== 1'b0)
            $fatal(1, "3893 Receiver 3-State, Transmit to Bus");
        de = 1'b0; re_n = 1'b1;
        #1;
        if (io_drive !== 4'h0 || r_out !== 4'h0)
            $fatal(1, "3893 driver released with receivers off");
        de = 1'b0; re_n = 1'b0; io_in = 4'h9;
        #1;
        if (io_drive !== 4'h0 || r_out !== 4'h6 || r_drive !== 1'b1)
            $fatal(1, "3893 Receive with I/O pins as inputs");

        $display("PASS: tb_ttl_74x3893");
        $finish;
    end
endmodule
