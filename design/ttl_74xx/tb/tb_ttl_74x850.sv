`timescale 1ns/1ps
// Reference-model testbench for ttl_74x850 (clocked-select 16:1 mux, 3-state
// complementary outputs). Covers all 16 selects (two data patterns), all 8
// output-control combinations, select-hold across a clock-less input change,
// and 2000 randomized steps.
module tb_ttl_74x850;
    logic        clk, g_n, gy_n, gw_n, y, w;
    logic [3:0]  s;
    logic [15:0] d;
    ttl_74x850 dut(.clk(clk), .s(s), .d(d), .g_n(g_n), .gy_n(gy_n), .gw_n(gw_n), .y(y), .w(w));

    logic [3:0] sel_r;
    int errors;
    function automatic logic dataf; return d[sel_r]; endfunction
    function automatic logic yf; return (!g_n && !gy_n) ?  dataf() : 1'b0; endfunction
    function automatic logic wf; return (!g_n && !gw_n) ? ~dataf() : 1'b0; endfunction

    task automatic chk(input string t);
        #1;
        if (y !== yf() || w !== wf()) begin
            $display("Mismatch [%s]: sel=%0d d=%h g=%b gy=%b gw=%b got y=%b w=%b exp y=%b w=%b",
                     t, sel_r, d, g_n, gy_n, gw_n, y, w, yf(), wf());
            errors++;
        end
    endtask
    task automatic cclk; clk=0; #1; clk=1; #1; sel_r=s; clk=0; #1; endtask

    logic [31:0] rnd;
    initial begin
        errors=0; clk=0; g_n=0; gy_n=0; gw_n=0; s=0; d=16'hAAAA; sel_r=4'dx;
        s=0; cclk; chk("init");

        for (int k=0; k<16; k++) begin
            s=k[3:0]; cclk;
            d=16'hAAAA; chk($sformatf("sel%0d A", k));
            d=16'h5555; chk($sformatf("sel%0d 5", k));
        end

        // output-control sweep, data=1 then data=0
        s=4'd5; cclk; d=16'hFFFF;
        for (int g=0; g<8; g++) begin {g_n,gy_n,gw_n}=g[2:0]; chk($sformatf("oc%0d hi", g)); end
        d=16'h0000;
        for (int g=0; g<8; g++) begin {g_n,gy_n,gw_n}=g[2:0]; chk($sformatf("oc%0d lo", g)); end
        g_n=0; gy_n=0; gw_n=0;

        // hold: load sel=3 (d[3]=1), change s with no clock -> select held
        s=4'd3; cclk; d=16'h0008;
        s=4'd7; chk("hold no-clk");

        rnd=$urandom(32'h0850_1234);
        for (int n=0; n<2000; n++) begin
            rnd=$urandom;
            s=rnd[3:0]; g_n=rnd[4]; gy_n=rnd[5]; gw_n=rnd[6];
            if (rnd[7]) cclk;
            rnd=$urandom; d=rnd[15:0];
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x850: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x850 (directed + 2000 random)");
        $finish;
    end
endmodule
