`timescale 1ns/1ps
// Reference-model + directed testbench for ttl_74x867. A behavioral model mirrors
// the mode-select counter and the rco_n carry; directed checks cover clear,
// load, count up/down, the up/down wraps and rco_n, enable hold, and the
// async clear, plus 2000 randomized steps.
module tb_ttl_74x867;
    logic       clk, s0, s1, enp_n, ent_n, rco_n;
    logic [7:0] d, q;
    ttl_74x867 dut(.clk(clk), .s0(s0), .s1(s1), .enp_n(enp_n), .ent_n(ent_n),
        .d(d), .q(q), .rco_n(rco_n));

    logic [7:0] cnt_r;
    function automatic logic exp_rco;
        return ent_n | ~(((s1 && s0) && (cnt_r == 8'hFF)) || ((!s1 && s0) && (cnt_r == 8'h00)));
    endfunction
    int errors;

    task automatic chk(input string t);
        #1;
        if (!s1 && !s0) cnt_r = 8'd0;
        if (q !== cnt_r) begin $display("Q [%s]: got %h exp %h (s=%b%b)", t, q, cnt_r, s1, s0); errors++; end
        if (rco_n !== exp_rco()) begin $display("RCO [%s]: got %b exp %b (cnt=%h s=%b%b ent_n=%b)", t, rco_n, exp_rco(), cnt_r, s1, s0, ent_n); errors++; end
    endtask

    task automatic tick;
        logic [7:0] nx;
        nx = cnt_r;
        case ({s1, s0})
            2'b00: nx = 8'd0;
            2'b01: if (!enp_n && !ent_n) nx = cnt_r - 8'd1;
            2'b10: nx = d;
            2'b11: if (!enp_n && !ent_n) nx = cnt_r + 8'd1;
        endcase
        clk=0; #1; clk=1; #1; cnt_r = nx; clk=0; #1;
    endtask

    logic [31:0] rnd;
    initial begin
        errors=0; clk=0; s0=0; s1=0; enp_n=0; ent_n=0; d=0; cnt_r=8'dx;

        // Clear.
        s1=0; s0=0; tick; chk("clear");
        if (cnt_r!==8'd0) begin $display("clear failed"); errors++; end
        // Load.
        s1=1; s0=0; d=8'hFE; tick; chk("load");
        // Count up to wrap (FE->FF->00).
        s1=1; s0=1; enp_n=0; ent_n=0; tick; chk("to FF");
        chk("rco up");      // at FF, counting up -> rco_n low
        tick; chk("wrap up 00");
        // Count down to wrap (00->FF).
        s1=0; s0=1; tick; chk("down to FF");
        // Load 1, count down to 0.
        s1=1; s0=0; d=8'd1; tick; s1=0; s0=1; tick; chk("down to 0");
        chk("rco down");    // at 0 counting down -> rco_n low
        // Enable hold.
        enp_n=1; tick; chk("hold enp"); enp_n=0;
        ent_n=1; tick; chk("hold ent"); ent_n=0;

        // Asynchronous clear: select clear mode with no clock edge.
        s1=1; s0=1; d=8'h55; tick;       // get a nonzero value
        s1=0; s0=0; cnt_r=8'd0; chk("async clear (no clk)");

        rnd=$urandom(32'h0363_5A5A);
        for (int n=0; n<2000; n++) begin
            rnd=$urandom;
            s0=rnd[0]; s1=rnd[1]; enp_n=rnd[2]; ent_n=rnd[3]; d=rnd[11:4];
            #1;
            if (!s1 && !s0) cnt_r = 8'd0;
            tick;
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x867: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x867 (directed + 2000 random)");
        $finish;
    end
endmodule
