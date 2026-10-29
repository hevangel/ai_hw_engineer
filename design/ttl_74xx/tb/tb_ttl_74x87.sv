// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps
module tb_ttl_74x87;
    logic [3:0] b, y, exp;
    logic s_complement, s_const;
    ttl_74x87 dut(.b(b), .s_complement(s_complement), .s_const(s_const), .y(y));
    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 64; i++) begin
            b = i[3:0]; s_complement = i[4]; s_const = i[5]; #1;
            case ({s_complement, s_const})
                2'b00: exp = b;
                2'b01: exp = ~b;
                2'b10: exp = 4'b0000;
                2'b11: exp = 4'b1111;
                default: exp = 4'b0000;
            endcase
            if (y !== exp) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x87: %0d errors", errors);
        $display("PASS: tb_ttl_74x87 (64 vectors)");
        $finish;
    end
endmodule
