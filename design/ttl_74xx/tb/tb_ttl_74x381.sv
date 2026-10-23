`timescale 1ns/1ps
module tb_ttl_74x381;
    logic [3:0] a, b, f;
    logic [2:0] s;
    logic cn, p, g;
    ttl_74x381 dut(.a(a), .b(b), .s(s), .cn(cn), .f(f), .p(p), .g(g));
    int errors;
    initial begin
        errors = 0;
        a=4'h5; b=4'h3; cn=1;
        s=3'b011; #1; if (f !== 4'h9) errors++; // 5+3+1=9
        s=3'b100; #1; if (f !== (a^b)) errors++;
        s=3'b110; #1; if (f !== (a&b)) errors++;
        s=3'b000; #1; if (f !== 0) errors++;
        s=3'b111; #1; if (f !== 4'hF) errors++;
        if (errors != 0) $fatal(1, "tb_ttl_74x381: %0d errors", errors);
        $display("PASS: tb_ttl_74x381");
        $finish;
    end
endmodule
