`timescale 1ns/1ps
module tb_ttl_74x646;
    logic g_n, dir, sab, sba, cab, cba;
    logic [7:0] a_in, b_in, a_out, b_out;
    logic a_oe_n, b_oe_n;
    ttl_74x646 dut(.*);
    int errors;

    task automatic clk_cab;
        cab = 0; #1; cab = 1; #1;
    endtask
    task automatic clk_cba;
        cba = 0; #1; cba = 1; #1;
    endtask

    initial begin
        errors = 0;
        g_n = 1; dir = 0; sab = 0; sba = 0; cab = 0; cba = 0;
        a_in = 0; b_in = 0; #1;

        // Disabled.
        if (a_out !== 0 || b_out !== 0) errors++;
        if (a_oe_n !== 1 || b_oe_n !== 1) errors++;

        // A->B real-time.
        g_n = 0; dir = 1; sab = 0; a_in = 8'h3C; #1;
        if (b_out !== 8'h3C) begin errors++; $display("A->B real-time fail: %h", b_out); end
        if (b_oe_n !== 0 || a_oe_n !== 1) errors++;

        // Capture into A->B latch then switch to stored mode.
        a_in = 8'hA5; clk_cab(); a_in = 8'h00; sab = 1; #1;
        if (b_out !== 8'hA5) begin errors++; $display("A->B stored fail: %h", b_out); end

        // B->A real-time.
        g_n = 0; dir = 0; sba = 0; b_in = 8'h77; #1;
        if (a_out !== 8'h77) begin errors++; $display("B->A real-time fail: %h", a_out); end
        if (a_oe_n !== 0 || b_oe_n !== 1) errors++;

        // Capture B->A then switch to stored.
        b_in = 8'h5A; clk_cba(); b_in = 8'hFF; sba = 1; #1;
        if (a_out !== 8'h5A) begin errors++; $display("B->A stored fail: %h", a_out); end

        // Disable while keeping stored data.
        g_n = 1; #1;
        if (a_out !== 0 || b_out !== 0) errors++;
        if (a_oe_n !== 1 || b_oe_n !== 1) errors++;

        // Latches still capture while g_n=1.
        a_in = 8'h81; clk_cab();
        b_in = 8'h18; clk_cba();
        g_n = 0; dir = 1; sab = 1; #1;
        if (b_out !== 8'h81) begin errors++; $display("latch-while-disabled A fail: %h", b_out); end
        dir = 0; sba = 1; #1;
        if (a_out !== 8'h18) begin errors++; $display("latch-while-disabled B fail: %h", a_out); end

        if (errors != 0) $fatal(1, "tb_ttl_74x646: %0d errors", errors);
        $display("PASS: tb_ttl_74x646");
        $finish;
    end
endmodule
