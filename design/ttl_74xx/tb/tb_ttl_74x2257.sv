`timescale 1ns/1ps
// Exhaustive testbench for ttl_74x2257: g_n(1)+select(1)+a(4)+b(4) = 10 bits
// (1024 vectors), all checked against the quad 2-to-1 mux with active-low
// output enable.
module tb_ttl_74x2257;
    logic       g_n, select;
    logic [3:0] a, b, y, expected;
    ttl_74x2257 dut(.g_n(g_n), .select(select), .a(a), .b(b), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < (1 << 10); v++) begin
            {g_n, select, b, a} = v[9:0];
            #1;
            expected = g_n ? 4'h0 : (select ? b : a);
            if (y !== expected) begin
                $display("Mismatch v=%0d: g_n=%b sel=%b a=%h b=%h got %h exp %h",
                         v, g_n, select, a, b, y, expected);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x2257: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x2257 (1024 vectors, exhaustive)");
        $finish;
    end
endmodule
