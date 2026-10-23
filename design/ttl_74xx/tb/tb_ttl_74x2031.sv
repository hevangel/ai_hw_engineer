`timescale 1ns/1ps
module tb_ttl_74x2031;
    logic       oea, oeb, oeb_n, lca, lcb, sel1, sel0;
    logic [8:0] a_in, b_in;
    logic [8:0] a_out, b_out, b_drive;
    logic       a_drive;
    logic [8:0] exp_a, exp_b;

    ttl_74x2031 dut(.*);

    initial begin
        // Phase A: thru mode (SEL=01), exhaustive enable sweep, two vectors.
        sel1 = 1'b0; sel0 = 1'b1; lca = 1'b0; lcb = 1'b0;
        for (int e = 0; e < 8; e++) begin
            oea = e[2]; oeb = e[1]; oeb_n = e[0];
            a_in = 9'b1_0101_1010;
            b_in = 9'b0_1100_1100;
            #1;
            exp_a = oea ? ~b_in : 9'h000;
            exp_b = (oeb && !oeb_n) ? a_in : 9'h000;
            if (a_drive !== oea || a_out !== exp_a ||
                b_drive !== exp_b || b_out !== 9'h000)
                $fatal(1, "2031 thru-mode enable sweep, vector 1, e=%0d", e);
            a_in = 9'b0_1010_0101;
            #1;
            exp_a = oea ? ~b_in : 9'h000;
            exp_b = (oeb && !oeb_n) ? a_in : 9'h000;
            if (a_drive !== oea || a_out !== exp_a ||
                b_drive !== exp_b || b_out !== 9'h000)
                $fatal(1, "2031 thru-mode enable sweep, vector 2, e=%0d", e);
        end

        // Phase B: latch mode (SEL=00) in both directions.
        sel1 = 1'b0; sel0 = 1'b0;
        oea = 1'b1; oeb = 1'b1; oeb_n = 1'b0;
        lca = 1'b0; lcb = 1'b0;                 // both latches transparent
        a_in = 9'h155; b_in = 9'h0F0;
        #1;
        if (b_drive !== a_in || a_out !== ~b_in)
            $fatal(1, "2031 transparent latches must track");
        lca = 1'b1; a_in = 9'h2AA;              // latch A->B
        #1;
        if (b_drive !== 9'h155)
            $fatal(1, "2031 A-to-B latch must hold when lca=1");
        lca = 1'b0;
        #1;
        if (b_drive !== 9'h2AA)
            $fatal(1, "2031 A-to-B latch must resume tracking");
        lcb = 1'b1; b_in = 9'h1C7;              // latch B->A
        #1;
        if (a_out !== ~9'h0F0)
            $fatal(1, "2031 B-to-A latch must hold when lcb=1");
        lcb = 1'b0;
        #1;
        if (a_out !== ~9'h1C7)
            $fatal(1, "2031 B-to-A latch must resume tracking");
        // Stored A data survives output disable and re-enable.
        lca = 1'b1;
        oeb = 1'b0; a_in = 9'h000;
        #1;
        if (b_drive !== 9'h000)
            $fatal(1, "2031 disabled B port must release");
        oeb = 1'b1;
        #1;
        if (b_drive !== 9'h2AA)
            $fatal(1, "2031 stored A data must reappear after re-enable");
        lca = 1'b0;

        // Phase C: flip-flop mode (SEL=10), rising-edge capture only.
        sel1 = 1'b1; sel0 = 1'b0;
        lca = 1'b0; lcb = 1'b0;
        a_in = 9'h0A0; b_in = 9'h03C;
        #1;
        lca = 1'b1;                             // capture 0A0
        #1;
        a_in = 9'h150;
        #1;
        if (b_drive !== 9'h0A0)
            $fatal(1, "2031 A-to-B flip-flop must hold captured data");
        lcb = 1'b1;                             // capture ~03C
        #1;
        b_in = 9'h0C3;
        #1;
        if (a_out !== ~9'h03C)
            $fatal(1, "2031 B-to-A flip-flop must hold captured data");
        // Falling edge must not capture.
        a_in = 9'h155; lca = 1'b0;
        #1;
        if (b_drive !== 9'h0A0)
            $fatal(1, "2031 flip-flop must ignore falling edge");
        lca = 1'b1;                             // capture 155
        #1;
        if (b_drive !== 9'h155)
            $fatal(1, "2031 flip-flop must capture on rising edge");

        // Phase D: mixed selection (SEL=11): A->B flip-flop, B->A latch.
        sel1 = 1'b1; sel0 = 1'b1;
        lca = 1'b0; lcb = 1'b0;
        a_in = 9'h081; b_in = 9'h07E;
        #1;
        lca = 1'b1;                             // FF captures 081
        #1;
        a_in = 9'h100;
        #1;
        if (b_drive !== 9'h081)
            $fatal(1, "2031 SEL=11 A-to-B must use the flip-flop");
        lcb = 1'b1; b_in = 9'h00F;              // latch holds 07E
        #1;
        if (a_out !== ~9'h07E)
            $fatal(1, "2031 SEL=11 B-to-A must use the latch");
        lcb = 1'b0;
        #1;
        if (a_out !== ~9'h00F)
            $fatal(1, "2031 SEL=11 B-to-A latch resumes transparently");

        // Phase E: storage stays live while thru is selected (documented
        // assumption), so switching to FF mode exposes the last captured data.
        sel1 = 1'b0; sel0 = 1'b1; lca = 1'b0; lcb = 1'b0;
        a_in = 9'h124; b_in = 9'h0DB;
        #1;
        lca = 1'b1; lcb = 1'b1;                 // capture during thru
        #1;
        a_in = 9'h000; b_in = 9'h000;
        #1;
        if (b_drive !== 9'h000 || a_out !== ~9'h000)
            $fatal(1, "2031 thru mode must show live inputs");
        sel1 = 1'b1; sel0 = 1'b0;
        #1;
        if (b_drive !== 9'h124 || a_out !== ~9'h0DB)
            $fatal(1, "2031 flip-flops must stay live while thru selected");

        // Phase F: isolation rows with stored content.
        oea = 1'b0; oeb = 1'b0;
        #1;
        if (a_drive !== 1'b0 || a_out !== 9'h000 || b_drive !== 9'h000)
            $fatal(1, "2031 isolation must release both ports");
        oea = 1'b0; oeb = 1'b1; oeb_n = 1'b1;
        #1;
        if (a_drive !== 1'b0 || b_drive !== 9'h000)
            $fatal(1, "2031 oeb_n high must disable the B port");
        oeb_n = 1'b0;

        $display("PASS: tb_ttl_74x2031");
        $finish;
    end
endmodule
