`timescale 1ns/1ps
module tb_ttl_74x162268;
    logic clk;
    logic [11:0] a_in, b1_in, b2_in;
    logic clkena1_n, clkena2_n, clken1b_n, clken2b_n, sel, oea_n, oeb_n;
    logic [11:0] a_out, b1_out, b2_out;
    logic a_drive, b_drive;
    ttl_74x162268 dut(.*);
    initial begin
        clk=0; a_in=0; b1_in=0; b2_in=0; clkena1_n=0; clkena2_n=0;
        clken1b_n=0; clken2b_n=0; sel=1; oea_n=0; oeb_n=0;
        a_in=12'hA5C; #1; clk=1; #1;
        if (!b_drive || b2_out !== 12'hA5C) $fatal(1,"A-to-2B one-edge path");
        clk=0; a_in=12'h39E; #1; clk=1; #1;
        if (b1_out !== 12'hA5C || b2_out !== 12'h39E) $fatal(1,"A-to-1B two-edge pipeline");
        clk=0; oeb_n=1; #1; clk=1; #1;
        if (b_drive || b1_out !== 12'h000 || b2_out !== 12'h000) $fatal(1,"registered OEB disable");
        clk=0; oeb_n=0; #1; clk=1; #1;
        if (!b_drive) $fatal(1,"registered OEB enable");
        clk=0; sel=1; b1_in=12'hD26; #1; clk=1; #1;
        clk=0; b1_in=12'h000; #1; clk=1; #1;
        if (!a_drive || a_out !== 12'hD26) $fatal(1,"B1-to-A two-edge pipeline");
        clk=0; clken1b_n=1; clken2b_n=0; b1_in=12'h4F3; #1; clk=1; #1;
        clk=0; #1; clk=1; #1;
        if (a_out !== 12'h000) $fatal(1,"CLKEN1B holds the independent first stage");
        clk=0; clken1b_n=0; clken2b_n=1; #1; clk=1; #1;
        if (a_out !== 12'h000) $fatal(1,"CLKEN2B holds the independent output stage");
        clk=0; clken1b_n=1; clken2b_n=0; #1; clk=1; #1;
        if (a_out !== 12'h4F3) $fatal(1,"B1 data advances only when both stage enables permit it");
        clk=0; sel=0; b2_in=12'h6B4; #1; clk=1; #1;
        if (a_out !== 12'h6B4) $fatal(1,"B2-to-A one-edge path");
        $display("PASS: tb_ttl_74x162268");
        $finish;
    end
endmodule
