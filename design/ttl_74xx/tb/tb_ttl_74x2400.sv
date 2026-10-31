`timescale 1ns/1ps
// Exhaustive testbench for ttl_74x2400: a1(4)+a2(4)+ng1(1)+ng2(1) = 10 bits
// (1024 vectors), all checked against the dual 4-bit inverting buffer with
// per-nibble active-high output disable (high-Z modeled as 0).
module tb_ttl_74x2400;
    logic [3:0] a1, a2, y1, y2, e1, e2;
    logic       ng1, ng2;
    ttl_74x2400 dut(.a1(a1), .a2(a2), .ng1(ng1), .ng2(ng2), .y1(y1), .y2(y2));
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < (1 << 10); v++) begin
            {ng2, ng1, a2, a1} = v[9:0];
            #1;
            e1 = ng1 ? 4'b0 : ~a1;
            e2 = ng2 ? 4'b0 : ~a2;
            if (y1 !== e1 || y2 !== e2) begin
                $display("Mismatch v=%0d: a1=%h a2=%h ng1=%b ng2=%b -> y1=%h(%h) y2=%h(%h)",
                         v, a1, a2, ng1, ng2, y1, e1, y2, e2);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x2400: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x2400 (1024 vectors, exhaustive)");
        $finish;
    end
endmodule
