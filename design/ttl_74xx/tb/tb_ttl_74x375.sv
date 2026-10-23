`timescale 1ns/1ps
module tb_ttl_74x375;
    logic [1:0] le;
    logic [3:0] d, q, q_n;
    ttl_74x375 dut(.le(le), .d(d), .q(q), .q_n(q_n));
    int errors;
    initial begin
        errors = 0;
        le=2'b11; d=4'hA; #1; if (q !== 4'hA) errors++;
        le=2'b00; d=4'hF; #1; if (q !== 4'hA) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x375: %0d errors", errors);
        $display("PASS: tb_ttl_74x375");
        $finish;
    end
endmodule
