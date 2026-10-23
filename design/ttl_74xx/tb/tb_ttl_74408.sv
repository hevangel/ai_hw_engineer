`timescale 1ns/1ps
module tb_ttl_74408;
    logic [7:0] data;
    logic parity;
    ttl_74408 dut(.data(data), .parity(parity));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 256; i++) begin
            data = i[7:0]; #1;
            if (parity !== ^data) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74408: %0d errors", errors);
        $display("PASS: tb_ttl_74408");
        $finish;
    end
endmodule
