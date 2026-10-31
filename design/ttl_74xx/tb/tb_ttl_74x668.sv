`timescale 1ns/1ps
module tb_ttl_74x668;
    logic clk, load_n, u_d_n, enp, ent;
    logic [3:0] d, q;
    logic rco_n;
    ttl_74x668 dut(.*);
    int errors;

    task automatic tick;
        clk = 0; #1; clk = 1; #1;
    endtask

    initial begin
        errors = 0;
        clk = 0; load_n = 1; u_d_n = 1; enp = 0; ent = 0; d = 0;

        // Sync load.
        load_n = 0; d = 4'd0; tick();
        if (q !== 0) errors++;
        load_n = 1;

        // Count up 0..9..0.
        u_d_n = 1; enp = 1; ent = 1;
        for (int i = 0; i < 20; i++) begin
            tick();
            if (q > 4'd9) errors++;
        end

        // Load 9, check RCO_n.
        load_n = 0; d = 4'd9; tick(); load_n = 1;
        if (rco_n !== 0) errors++;
        if (q !== 9) errors++;
        // Next tick wraps to 0.
        tick();
        if (q !== 0) errors++;
        if (rco_n !== 1) errors++;

        // Disable counter (ent=0): RCO_n must read 1 regardless of q.
        load_n = 0; d = 4'd9; tick(); load_n = 1;
        ent = 0; #1;
        if (rco_n !== 1) errors++;
        ent = 1; #1;
        if (rco_n !== 0) errors++;

        // Count down sweep.
        u_d_n = 0;
        for (int i = 0; i < 20; i++) begin
            tick();
        end

        // Down from 0 wraps to 9.
        load_n = 0; d = 4'd0; tick(); load_n = 1;
        if (q !== 0) errors++;
        if (rco_n !== 0) errors++;
        tick();
        if (q !== 9) errors++;

        // Hold (enp=0 or ent=0).
        load_n = 0; d = 4'd5; tick(); load_n = 1;
        enp = 0; tick();
        if (q !== 5) errors++;
        enp = 1; ent = 0; tick();
        if (q !== 5) errors++;

        if (errors != 0) $fatal(1, "tb_ttl_74x668: %0d errors", errors);
        $display("PASS: tb_ttl_74x668");
        $finish;
    end
endmodule
