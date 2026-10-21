`timescale 1ns/1ps
module tb_ttl_74x1403;
    logic rx_clk, rx_oe_n;
    logic [7:0] bus_in, rx_out;
    logic rx_hiz;
    logic tx_clk, tx_oe_n;
    logic [3:0] tx_in, bus_out;
    logic tx_hiz;
    ttl_74x1403 dut(.*);
    int errors;
    initial begin
        errors = 0;
        rx_clk = 0; rx_oe_n = 0; tx_clk = 0; tx_oe_n = 0;
        bus_in = 8'h5A; tx_in = 4'hB;
        #1; rx_clk = 1; tx_clk = 1; #1;
        if (rx_out !== 8'h5A) errors++;
        if (bus_out !== 4'hB) errors++;
        rx_oe_n = 1; tx_oe_n = 1; #1;
        if (rx_hiz !== 1 || tx_hiz !== 1) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x1403: %0d errors", errors);
        $display("PASS: tb_ttl_74x1403");
        $finish;
    end
endmodule
