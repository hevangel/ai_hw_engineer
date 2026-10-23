`timescale 1ns/1ps
// Reference-model testbench for ttl_74x851 (latched-select 16:1 mux, 3-state
// complementary outputs). The select latch is transparent while sc_n is low.
// Covers all 16 selects, all 8 output-control combinations, latch-hold while
// sc_n is high, and 2000 randomized steps.
module tb_ttl_74x851;
    logic        sc_n, g_n, gy_n, gw_n, y, w;
    logic [3:0]  s;
    logic [15:0] d;
    ttl_74x851 dut(.sc_n(sc_n), .s(s), .d(d), .g_n(g_n), .gy_n(gy_n), .gw_n(gw_n), .y(y), .w(w));

    logic [3:0] sel_r;
    int errors;
    function automatic logic dataf; return d[sel_r]; endfunction
    function automatic logic yf; return (!g_n && !gy_n) ?  dataf() : 1'b0; endfunction
    function automatic logic wf; return (!g_n && !gw_n) ? ~dataf() : 1'b0; endfunction

    task automatic chk(input string t);
        #1;
        if (!sc_n) sel_r = s;            // transparent latch (mirror DUT)
        if (y !== yf() || w !== wf()) begin
            $display("Mismatch [%s]: sc_n=%b sel=%0d d=%h g=%b gy=%b gw=%b got y=%b w=%b exp y=%b w=%b",
                     t, sc_n, sel_r, d, g_n, gy_n, gw_n, y, w, yf(), wf());
            errors++;
        end
    endtask

    logic [31:0] rnd;
    initial begin
        errors=0; sc_n=0; g_n=0; gy_n=0; gw_n=0; s=0; d=16'hAAAA; sel_r=4'dx;
        chk("init");

        for (int k=0; k<16; k++) begin
            sc_n=0; s=k[3:0];
            d=16'hAAAA; chk($sformatf("sel%0d A", k));
            d=16'h5555; chk($sformatf("sel%0d 5", k));
        end

        sc_n=0; s=4'd5; chk("set5"); d=16'hFFFF;
        for (int g=0; g<8; g++) begin {g_n,gy_n,gw_n}=g[2:0]; chk($sformatf("oc%0d hi", g)); end
        d=16'h0000;
        for (int g=0; g<8; g++) begin {g_n,gy_n,gw_n}=g[2:0]; chk($sformatf("oc%0d lo", g)); end
        g_n=0; gy_n=0; gw_n=0;

        // latch-hold: capture sel=3 (transparent), raise sc_n, change s -> held
        sc_n=0; s=4'd3; d=16'h0008; chk("cap3");
        sc_n=1; s=4'd7; chk("hold high");   // sel held at 3, data=d[3]=1

        rnd=$urandom(32'h0851_5678);
        for (int n=0; n<2000; n++) begin
            rnd=$urandom;
            sc_n=rnd[0]; s=rnd[4:1]; g_n=rnd[5]; gy_n=rnd[6]; gw_n=rnd[7];
            rnd=$urandom; d=rnd[15:0];
            chk($sformatf("rand%0d", n));
        end

        if (errors!=0) $fatal(1, "tb_ttl_74x851: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x851 (directed + 2000 random)");
        $finish;
    end
endmodule
