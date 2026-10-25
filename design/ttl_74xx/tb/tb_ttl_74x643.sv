`timescale 1ns/1ps
module tb_ttl_74x643;
    logic gab, gba_n;
    logic [7:0] a_in, b_in, a_out, b_out;
    ttl_74x643 dut(.*);
    int errors;
    initial begin
        errors = 0;

        // A->B enabled (non-inverting), B->A disabled.
        gab = 1; gba_n = 1; a_in = 8'h42; b_in = 8'hA5; #1;
        if (b_out !== 8'h42) begin errors++; $display("A->B fail: got %h", b_out); end
        if (a_out !== 8'h00) begin errors++; $display("A disabled fail: got %h", a_out); end

        // B->A enabled (inverting), A->B disabled.
        gab = 0; gba_n = 0; a_in = 8'hFF; b_in = 8'h0F; #1;
        if (a_out !== 8'hF0) begin errors++; $display("B->A fail: got %h", a_out); end
        if (b_out !== 8'h00) begin errors++; $display("B disabled fail: got %h", b_out); end

        // Both disabled.
        gab = 0; gba_n = 1; a_in = 8'hAA; b_in = 8'h55; #1;
        if (a_out !== 8'h00 || b_out !== 8'h00) begin
            errors++; $display("both-disabled fail: a=%h b=%h", a_out, b_out);
        end

        // Both enabled (feedback config): A drives b_out from a_in, A drives a_out from ~b_in.
        gab = 1; gba_n = 0; a_in = 8'h33; b_in = 8'hCC; #1;
        if (b_out !== 8'h33) begin errors++; $display("dual A->B fail: got %h", b_out); end
        if (a_out !== 8'h33) begin errors++; $display("dual B->A fail: got %h", a_out); end

        // Exhaustive: every input pattern in one direction at a time.
        gab = 1; gba_n = 1;
        for (int v = 0; v < 256; v++) begin
            a_in = v[7:0]; b_in = 8'h00; #1;
            if (b_out !== v[7:0]) begin
                errors++; $display("sweep A->B v=%0d got=%h", v, b_out);
            end
        end
        gab = 0; gba_n = 0;
        for (int v = 0; v < 256; v++) begin
            b_in = v[7:0]; a_in = 8'h00; #1;
            if (a_out !== ~v[7:0]) begin
                errors++; $display("sweep B->A v=%0d got=%h", v, a_out);
            end
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x643: %0d errors", errors);
        $display("PASS: tb_ttl_74x643");
        $finish;
    end
endmodule
