`timescale 1ns/1ps
module tb_ttl_74x834;
    logic clk, clr_n, oea_n, oeb_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic parity_in, parity_out, err_n;
    logic a_oe_n, b_oe_n, parity_oe_n;
    ttl_74x834 dut(.*);
    int errors;
    task automatic tick;
        clk = 0; #1; clk = 1; #1;
    endtask
    initial begin
        errors = 0;
        clk = 0; clr_n = 1; oea_n = 1; oeb_n = 1;
        a_in = 0; b_in = 0; parity_in = 0; #1;
        clr_n = 0; #1; if (err_n !== 1) errors++;
        clr_n = 1;

        // Transmit: inverted B output, odd parity over inverted data.
        oea_n = 1; oeb_n = 0; a_in = 8'h0F; #1;
        if (b_out !== 8'hF0) errors++;
        if (parity_out !== 1) errors++;  // ^0F=0, ~^a=1
        // Receive: inverted A output.
        oea_n = 0; oeb_n = 1; b_in = 8'h33; parity_in = 0; #1;
        if (a_out !== 8'hCC) errors++;
        // Error sample.
        tick();  // ^33=0, parity_in=0 → point_p=0 → err=0
        if (err_n !== 0) errors++;
        clr_n = 0; #1; if (err_n !== 1) errors++; clr_n = 1;
        // No-error sample.
        b_in = 8'h33; parity_in = 1; tick();  // 0^1=1 → no error
        if (err_n !== 1) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x834: %0d errors", errors);
        $display("PASS: tb_ttl_74x834");
        $finish;
    end
endmodule
