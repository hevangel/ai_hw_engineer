`timescale 1ns/1ps
// Exhaustive testbench for ttl_74x1181 (4-bit ALU, '181 family). All 2^14 = 16384
// combinations of {a, b, s, m, cn} are checked against a reference model of the
// SN74181 function table (active-high operands), including the F outputs and
// the carry / A=B / P / G outputs.
module tb_ttl_74x1181;
    logic [3:0] a, b, s;
    logic       m, cn;
    logic [3:0] f;
    logic       cn_p_4, a_eq_b, p_n, g_n;
    ttl_74x1181 dut(.a(a), .b(b), .s(s), .m(m), .cn(cn), .f(f),
        .cn_p_4(cn_p_4), .a_eq_b(a_eq_b), .p_n(p_n), .g_n(g_n));

    int errors;

    function automatic logic [3:0] ref_logic(input logic [3:0] aa, bb, ss);
        case (ss)
            4'h0: return ~aa;
            4'h1: return ~(aa | bb);
            4'h2: return (~aa) & bb;
            4'h3: return 4'h0;
            4'h4: return ~(aa & bb);
            4'h5: return ~bb;
            4'h6: return aa ^ bb;
            4'h7: return aa & (~bb);
            4'h8: return (~aa) | bb;
            4'h9: return ~(aa ^ bb);
            4'hA: return bb;
            4'hB: return aa & bb;
            4'hC: return 4'hF;
            4'hD: return aa | (~bb);
            4'hE: return aa | bb;
            4'hF: return aa;
        endcase
        return 4'h0;
    endfunction

    function automatic logic [4:0] ref_arith(input logic [3:0] aa, bb, ss, input logic c);
        case (ss)
            4'h0: return {1'b0, aa} + {4'b0, c};
            4'h1: return {1'b0, (aa | bb)} + {4'b0, c};
            4'h2: return {1'b0, (aa | (~bb))} + {4'b0, c};
            4'h3: return 5'h1F + {4'b0, c};
            4'h4: return {1'b0, aa} + {1'b0, (aa & (~bb))} + {4'b0, c};
            4'h5: return {1'b0, (aa | bb)} + {1'b0, (aa & (~bb))} + {4'b0, c};
            4'h6: return {1'b0, aa} + {1'b0, (~bb)} + {4'b0, c};
            4'h7: return {1'b0, (aa & (~bb))} + 5'h1F + {4'b0, c};
            4'h8: return {1'b0, aa} + {1'b0, (aa & bb)} + {4'b0, c};
            4'h9: return {1'b0, aa} + {1'b0, bb} + {4'b0, c};
            4'hA: return {1'b0, (aa | (~bb))} + {1'b0, (aa & bb)} + {4'b0, c};
            4'hB: return {1'b0, (aa & bb)} + 5'h1F + {4'b0, c};
            4'hC: return {1'b0, aa} + {1'b0, aa} + {4'b0, c};
            4'hD: return {1'b0, (aa | bb)} + {1'b0, aa} + {4'b0, c};
            4'hE: return {1'b0, (aa | (~bb))} + {1'b0, aa} + {4'b0, c};
            4'hF: return {1'b0, aa} + 5'h1F + {4'b0, c};
        endcase
        return 5'h00;
    endfunction

    initial begin
        errors = 0;
        for (int v = 0; v < (1 << 14); v++) begin
            {cn, m, s, b, a} = v[13:0];
            #1;
            begin
                logic [3:0] ef;
                logic       ecn, eab, epn, egn;
                logic [4:0] ar;
                ar  = ref_arith(a, b, s, cn);
                ef  = m ? ref_logic(a, b, s) : ar[3:0];
                ecn = m ? 1'b1 : ar[4];
                eab = (ef == 4'hF);
                epn = ~|ef;
                egn = ~ar[4];
                if (f !== ef || cn_p_4 !== ecn || a_eq_b !== eab || p_n !== epn || g_n !== egn) begin
                    $display("Mismatch v=%0d: a=%h b=%h s=%h m=%b cn=%b -> f=%h(exp %h) cn4=%b(%b) aeqb=%b(%b) pn=%b(%b) gn=%b(%b)",
                             v, a, b, s, m, cn, f, ef, cn_p_4, ecn, a_eq_b, eab, p_n, epn, g_n, egn);
                    errors++;
                end
            end
        end
        if (errors != 0) $fatal(1, "tb_ttl_74x1181: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x1181 (16384 vectors, exhaustive)");
        $finish;
    end
endmodule
