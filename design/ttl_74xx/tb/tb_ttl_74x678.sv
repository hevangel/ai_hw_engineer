`timescale 1ns/1ps
// Testbench for ttl_74x678 (16-bit comparator with transparent output latch).
// Covers: (1) transparent-mode comparison against the datasheet rows, (2)
// explicit latch hold sequences, and (3) a long random sequence with C toggling
// where the expected value updates only while C is high.
module tb_ttl_74x678;
    logic        c;
    logic [3:0]  p;
    logic [16:1] a;
    logic        y;
    logic        exp;       // expected latch state
    int errors;

    ttl_74x678 dut (.c(c), .p(p), .a(a), .y(y));

    function automatic logic ref_match(input logic [3:0] pp, input logic [16:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 16; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return m;
    endfunction

    function automatic logic [16:1] match_addr(input int k);
        logic [16:1] aa;
        for (int i = 1; i <= 16; i++) aa[i] = (i <= k) ? 1'b0 : 1'b1;
        return aa;
    endfunction

    // Drive one step; update expected only while transparent (C high).
    task automatic step(input logic cc, input logic [3:0] pp,
                        input logic [16:1] aa, input string tag);
        c = cc; p = pp; a = aa;
        #1;
        if (cc) exp = ~ref_match(pp, aa);   // transparent: follow compare
        if (y !== exp) begin
            $display("Mismatch [%s]: c=%b p=%b a=%b -> got %b exp %b",
                     tag, c, p, a, y, exp);
            errors++;
        end
    endtask

    logic [31:0] r;
    initial begin
        errors = 0;

        // Establish a known latch state in transparent mode.
        step(1'b1, 4'd0, match_addr(0), "init");

        // 1. Transparent-mode directed: every datasheet threshold.
        for (int k = 0; k <= 15; k++) begin
            step(1'b1, k[3:0], match_addr(k),               $sformatf("k=%0d match", k));
            step(1'b1, k[3:0], match_addr(k) ^ 16'h1,       $sformatf("k=%0d flip1", k));
            step(1'b1, k[3:0], match_addr(k) ^ 16'h8000,    $sformatf("k=%0d flip16", k));
        end

        // 2. Explicit hold sequences: latch a value, then prove it holds while
        //    inputs change, and resumes tracking when C goes high again.
        step(1'b1, 4'd7, match_addr(7),  "hold:set0");   // y=0 (match), exp=0
        step(1'b0, 4'd7, match_addr(7),  "hold:latch");  // C low -> hold 0
        step(1'b0, 4'd7, 16'h0000,       "hold:chgA");   // change A -> still 0
        step(1'b0, 4'd2, 16'hFFFF,       "hold:chgP");   // change P -> still 0
        step(1'b1, 4'd2, 16'hFFFF,       "hold:open");   // C high -> follow (mismatch ->1)

        step(1'b1, 4'd3, match_addr(3),  "hold:set1");   // y=0 again
        step(1'b0, 4'd3, match_addr(3),  "hold:latch2"); // hold 0
        step(1'b0, 4'd0, match_addr(0),  "hold:chg2");   // would-be 0 anyway, still 0
        step(1'b0, 4'd5, match_addr(4),  "hold:chg3");   // mismatch underneath, held 0
        step(1'b1, 4'd5, match_addr(4),  "hold:open2");  // follow -> 1

        // 3. Random sequence with C toggling.
        r = $urandom(32'h0678_1234);
        for (int n = 0; n < 2000; n++) begin
            r = $urandom;
            step(r[0], r[5:2], r[21:6], $sformatf("rand %0d", n));
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x678: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x678 (directed + hold sequences + 2000 random)");
        $finish;
    end
endmodule
