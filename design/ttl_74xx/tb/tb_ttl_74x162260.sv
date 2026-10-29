`timescale 1ns/1ps
module tb_ttl_74x162260;
    logic [11:0] a_in, b1_in, b2_in;
    logic sel, le1b, le2b, lea1b, lea2b, oea_n, oe1b_n, oe2b_n;
    logic [11:0] a_out, b1_out, b2_out;
    logic a_drive, b1_drive, b2_drive;
    ttl_74x162260 dut(.*);
    initial begin
        a_in=0; b1_in=0; b2_in=0; sel=0; le1b=0; le2b=0;
        lea1b=1; lea2b=1; oea_n=1; oe1b_n=0; oe2b_n=0;
        #1; a_in=12'hA35; #1;
        if (b1_out !== 12'hA35 || b2_out !== 12'hA35) $fatal(1,"A-to-B transparent latches");
        lea1b=0; lea2b=0; a_in=12'h5C2; #1;
        if (b1_out !== 12'hA35 || b2_out !== 12'hA35) $fatal(1,"A-to-B independent hold");
        lea1b=1; a_in=12'h76B; #1;
        if (b1_out !== 12'h76B || b2_out !== 12'hA35) $fatal(1,"A-to-B independent latch enable");
        oea_n=0; oe1b_n=1; oe2b_n=1; sel=1; le1b=1; b1_in=12'hC69; #1;
        if (!a_drive || a_out !== 12'hC69) $fatal(1,"B1-to-A transparent path");
        le1b=0; b1_in=12'h135; #1;
        if (a_out !== 12'hC69) $fatal(1,"B1-to-A hold");
        sel=0; le2b=1; b2_in=12'h987; #1;
        if (a_out !== 12'h987) $fatal(1,"SEL chooses B2");
        oea_n=1; oe1b_n=1; oe2b_n=1; #1;
        if (a_drive || b1_drive || b2_drive || a_out !== 12'h000 || b1_out !== 12'h000 || b2_out !== 12'h000)
            $fatal(1,"disabled outputs must be masked");
        $display("PASS: tb_ttl_74x162260");
        $finish;
    end
endmodule
