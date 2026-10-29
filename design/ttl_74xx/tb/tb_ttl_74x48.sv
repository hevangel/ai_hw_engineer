// SPDX-License-Identifier: MIT
// Derived from sn74xx_sv; see references/LICENSE.sn74xx_sv.
`timescale 1ns/1ps

module tb_ttl_74x48;
    logic [3:0] bcd;
    logic lt_n, bi_n, rbi_n;
    logic [6:0] seg, exp_seg;
    logic rbo_n, exp_rbo_n;
    ttl_74x48 dut (.bcd(bcd), .lt_n(lt_n), .bi_n(bi_n), .rbi_n(rbi_n),
                   .seg(seg), .rbo_n(rbo_n));

    function automatic [6:0] decode_ah(input [3:0] b);
        case (b)
            4'h0: decode_ah = 7'b1111110;
            4'h1: decode_ah = 7'b0110000;
            4'h2: decode_ah = 7'b1101101;
            4'h3: decode_ah = 7'b1111001;
            4'h4: decode_ah = 7'b0110011;
            4'h5: decode_ah = 7'b1011011;
            4'h6: decode_ah = 7'b0011111;
            4'h7: decode_ah = 7'b1110000;
            4'h8: decode_ah = 7'b1111111;
            4'h9: decode_ah = 7'b1110011;
            4'hA: decode_ah = 7'b0001101;
            4'hB: decode_ah = 7'b0011001;
            4'hC: decode_ah = 7'b0100011;
            4'hD: decode_ah = 7'b1001011;
            4'hE: decode_ah = 7'b0001111;
            4'hF: decode_ah = 7'b0000000;
            default: decode_ah = 7'b0000000;
        endcase
    endfunction

    int errors;
    initial begin
        errors = 0;
        for (int i = 0; i < 128; i++) begin
            bcd = i[3:0]; rbi_n = i[4]; lt_n = i[5]; bi_n = i[6]; #1;
            if (!bi_n) begin
                exp_seg = 7'b0000000; exp_rbo_n = 1'b0;
            end else if (!lt_n) begin
                exp_seg = 7'b1111111; exp_rbo_n = 1'b1;
            end else if (!rbi_n && bcd == 4'h0) begin
                exp_seg = 7'b0000000; exp_rbo_n = 1'b0;
            end else begin
                exp_seg = decode_ah(bcd); exp_rbo_n = 1'b1;
            end
            if (seg !== exp_seg || rbo_n !== exp_rbo_n) errors++;
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x48: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x48 (128 vectors)");
        $finish;
    end
endmodule
