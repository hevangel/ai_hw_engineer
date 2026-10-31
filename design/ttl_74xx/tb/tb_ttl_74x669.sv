`timescale 1ns/1ps
module tb_ttl_74x669;
    logic clk, load_n, u_d_n, enp, ent;
    logic [3:0] d, q;
    logic rco_n;
    ttl_74x669 dut(.*);
    int errors;

    task automatic tick;
        clk = 0; #1; clk = 1; #1;
    endtask

    initial begin
        errors = 0;
        clk = 0; load_n = 1; u_d_n = 1; enp = 0; ent = 0; d = 0;

        load_n = 0; d = 4'd0; tick(); load_n = 1;
        if (q !== 0) errors++;

        u_d_n = 1; enp = 1; ent = 1;
        for (int i = 0; i < 16; i++) tick();
        if (q !== 0) errors++;  // wrapped a full cycle

        load_n = 0; d = 4'hF; tick(); load_n = 1;
        if (q !== 4'hF || rco_n !== 0) errors++;
        tick();
        if (q !== 0 || rco_n !== 1) errors++;

        u_d_n = 0;
        load_n = 0; d = 4'h0; tick(); load_n = 1;
        if (q !== 0 || rco_n !== 0) errors++;
        tick();
        if (q !== 4'hF) errors++;

        // Hold.
        load_n = 0; d = 4'd7; tick(); load_n = 1;
        enp = 0; tick();
        if (q !== 4'd7) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x669: %0d errors", errors);
        $display("PASS: tb_ttl_74x669");
        $finish;
    end
endmodule
