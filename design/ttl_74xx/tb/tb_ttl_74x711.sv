`timescale 1ns/1ps
// Exhaustive testbench for ttl_74x711: da(5)+db(5)+s(1)+oe_n(1) = 12 bits
// (4096 vectors), all checked against the quint 2-to-1 mux with common select
// and common active-low 3-state enable (datasheet 'F711 Function Table).
module tb_ttl_74x711;
    logic [4:0] da, db, q, expected;
    logic       s, oe_n;
    ttl_74x711 dut(.da(da), .db(db), .s(s), .oe_n(oe_n), .q(q));
    int errors;
    initial begin
        errors = 0;
        for (int v = 0; v < (1 << 12); v++) begin
            {oe_n, s, db, da} = v[11:0];
            #1;
            expected = oe_n ? 5'b0 : (s ? db : da);
            if (q !== expected) begin
                $display("Mismatch v=%0d: oe_n=%b s=%b da=%b db=%b got %b exp %b",
                         v, oe_n, s, da, db, q, expected);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x711: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x711 (4096 vectors, exhaustive)");
        $finish;
    end
endmodule
