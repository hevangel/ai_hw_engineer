// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x245;
    logic oe_n, dir;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;

    ttl_74x245 dut (
        .oe_n(oe_n), .dir(dir),
        .a_in(a_in), .b_in(b_in),
        .a_out(a_out), .b_out(b_out),
        .a_oe_n(a_oe_n), .b_oe_n(b_oe_n)
    );

    int errors;
    initial begin
        errors = 0;
        // oe disabled
        oe_n = 1'b1; dir = 1'b1; a_in = 8'hAA; b_in = 8'h55; #1;
        if (a_out !== 8'h00 || b_out !== 8'h00 ||
            a_oe_n !== 1'b1 || b_oe_n !== 1'b1) errors++;
        oe_n = 1'b1; dir = 1'b0; #1;
        if (a_out !== 8'h00 || b_out !== 8'h00 ||
            a_oe_n !== 1'b1 || b_oe_n !== 1'b1) errors++;

        // A->B
        oe_n = 1'b0; dir = 1'b1; a_in = 8'h5A; b_in = 8'hFF; #1;
        if (b_out !== 8'h5A || a_out !== 8'h00 ||
            b_oe_n !== 1'b0 || a_oe_n !== 1'b1) errors++;

        // B->A
        oe_n = 1'b0; dir = 1'b0; a_in = 8'hFF; b_in = 8'hA5; #1;
        if (a_out !== 8'hA5 || b_out !== 8'h00 ||
            a_oe_n !== 1'b0 || b_oe_n !== 1'b1) errors++;

        // Random sweep
        for (int i = 0; i < 64; i++) begin
            oe_n = i[0]; dir = i[1];
            a_in = i[7:0]; b_in = ~i[7:0];
            #1;
            if (oe_n) begin
                if (a_out !== 8'h00 || b_out !== 8'h00 ||
                    a_oe_n !== 1'b1 || b_oe_n !== 1'b1) errors++;
            end else if (dir) begin
                if (b_out !== a_in || a_out !== 8'h00 ||
                    a_oe_n !== 1'b1 || b_oe_n !== 1'b0) errors++;
            end else begin
                if (a_out !== b_in || b_out !== 8'h00 ||
                    a_oe_n !== 1'b0 || b_oe_n !== 1'b1) errors++;
            end
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x245: %0d errors", errors);
        $display("PASS: tb_ttl_74x245");
        $finish;
    end
endmodule
