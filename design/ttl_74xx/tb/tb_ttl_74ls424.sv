`timescale 1ns/1ps
module tb_ttl_74ls424;
    logic clk, rst, phi1, phi2, reset_out;
    ttl_74ls424 dut(.clk(clk), .rst(rst), .phi1(phi1), .phi2(phi2), .reset_out(reset_out));
    task automatic tick; clk=0; #1; clk=1; #1; clk=0; #1; endtask
    int errors;
    initial begin
        errors = 0;
        clk=0; rst=1; #1;
        if (phi1 !== 1) errors++;
        rst=0;
        tick; if (phi1 !== 0) errors++;
        tick; if (phi2 !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74ls424: %0d errors", errors);
        $display("PASS: tb_ttl_74ls424");
        $finish;
    end
endmodule
