`timescale 1ns/1ps
// Exhaustive testbench for ttl_74x712: da(5)+db(5)+dc(5)+s0(1)+s1(1) = 17 bits
// (131072 vectors), all checked against the quint 3-to-1 mux (datasheet 'F712
// Function Table: S1 high -> c; else S0 selects a/b).
module tb_ttl_74x712;
    logic [4:0] da, db, dc, q, expected;
    logic       s0, s1;
    ttl_74x712 dut(.da(da), .db(db), .dc(dc), .s0(s0), .s1(s1), .q(q));
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < (1 << 17); v++) begin
            {s1, s0, dc, db, da} = v[16:0];
            #1;
            expected = s1 ? dc : (s0 ? db : da);
            if (q !== expected) begin
                $display("Mismatch v=%0d: s1=%b s0=%b a=%b b=%b c=%b got %b exp %b",
                         v, s1, s0, da, db, dc, q, expected);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x712: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x712 (131072 vectors, exhaustive)");
        $finish;
    end
endmodule
