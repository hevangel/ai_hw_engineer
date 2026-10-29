`timescale 1ns/1ps
// Exhaustive testbench for ttl_74x882 (32-bit look-ahead carry generator). All
// 2^17 = 131072 combinations of {cn, p_n[7:0], g_n[7:0]} are checked against a
// reference model of the datasheet carry equations.
module tb_ttl_74x882;
    logic       cn;
    logic [7:0] p_n, g_n;
    logic       cn_p_8, cn_p_16, cn_p_24, cn_p_32;
    ttl_74x882 dut(.cn(cn), .p_n(p_n), .g_n(g_n),
        .cn_p_8(cn_p_8), .cn_p_16(cn_p_16), .cn_p_24(cn_p_24), .cn_p_32(cn_p_32));

    int errors;

    initial begin
        errors = 0;
        for (int v = 0; v < (1 << 17); v++) begin
            {cn, g_n, p_n} = v[16:0];
            #1;
            begin
                logic [7:0] p, g;
                logic e8, e16, e24, e32;
                p = ~p_n; g = ~g_n;
                e8  = g[1] | (p[1]&g[0]) | (p[1]&p[0]&cn);
                e16 = g[3] | (p[3]&g[2]) | (p[3]&p[2]&g[1]) | (p[3]&p[2]&p[1]&g[0])
                      | (p[3]&p[2]&p[1]&p[0]&cn);
                e24 = g[5] | (p[5]&g[4]) | (p[5]&p[4]&g[3]) | (p[5]&p[4]&p[3]&g[2])
                      | (p[5]&p[4]&p[3]&p[2]&g[1]) | (p[5]&p[4]&p[3]&p[2]&p[1]&g[0])
                      | (p[5]&p[4]&p[3]&p[2]&p[1]&p[0]&cn);
                e32 = g[7] | (p[7]&g[6]) | (p[7]&p[6]&g[5]) | (p[7]&p[6]&p[5]&g[4])
                      | (p[7]&p[6]&p[5]&p[4]&g[3]) | (p[7]&p[6]&p[5]&p[4]&p[3]&g[2])
                      | (p[7]&p[6]&p[5]&p[4]&p[3]&p[2]&g[1])
                      | (p[7]&p[6]&p[5]&p[4]&p[3]&p[2]&p[1]&g[0])
                      | (p[7]&p[6]&p[5]&p[4]&p[3]&p[2]&p[1]&p[0]&cn);
                if (cn_p_8 !== e8 || cn_p_16 !== e16 || cn_p_24 !== e24 || cn_p_32 !== e32) begin
                    $display("Mismatch v=%0d: cn=%b p_n=%h g_n=%h -> 8=%b(%b) 16=%b(%b) 24=%b(%b) 32=%b(%b)",
                             v, cn, p_n, g_n, cn_p_8, e8, cn_p_16, e16, cn_p_24, e24, cn_p_32, e32);
                    errors++;
                end
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x882: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x882 (131072 vectors, exhaustive)");
        $finish;
    end
endmodule
