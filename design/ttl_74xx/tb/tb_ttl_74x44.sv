// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x44;
    logic [3:0] g;
    logic [9:0] y_n, expected;
    ttl_74x44 dut (.g(g), .y_n(y_n));
    int errors;

    function automatic [9:0] expect_y(input [3:0] gv);
        logic [9:0] r;
        r = 10'b1111111111;
        case (gv)
            4'b0010: r[0] = 1'b0;
            4'b0110: r[1] = 1'b0;
            4'b0111: r[2] = 1'b0;
            4'b0101: r[3] = 1'b0;
            4'b0100: r[4] = 1'b0;
            4'b1100: r[5] = 1'b0;
            4'b1101: r[6] = 1'b0;
            4'b1111: r[7] = 1'b0;
            4'b1110: r[8] = 1'b0;
            4'b1010: r[9] = 1'b0;
            default: ;
        endcase
        return r;
    endfunction

    initial begin
        errors = 0;
        for (int i = 0; i < 16; i++) begin
            g = i[3:0]; #1;
            expected = expect_y(g);
            if (y_n !== expected) begin
                $display("FAIL g=%b y_n=%b expected=%b", g, y_n, expected);
                errors++;
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x44: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x44 (16 vectors)");
        $finish;
    end
endmodule
