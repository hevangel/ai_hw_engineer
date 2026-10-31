`timescale 1ns/1ps
// Testbench for ttl_74x680 (12-bit comparator with transparent output latch).
// Covers transparent-mode comparison against the datasheet rows, explicit latch
// hold sequences, and a long random sequence with C toggling (expected value
// updates only while C is high).
module tb_ttl_74x680;
    logic        c;
    logic [3:0]  p;
    logic [12:1] a;
    logic        y;
    logic        exp;
    int errors;

    ttl_74x680 dut (.c(c), .p(p), .a(a), .y(y));

    function automatic logic ref_match(input logic [3:0] pp, input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return m;
    endfunction

    function automatic logic [12:1] match_addr(input int k);
        logic [12:1] aa;
        for (int i = 1; i <= 12; i++) aa[i] = (i <= k) ? 1'b0 : 1'b1;
        return aa;
    endfunction

    task automatic step(input logic cc, input logic [3:0] pp,
                        input logic [12:1] aa, input string tag);
        c = cc; p = pp; a = aa;
        #1;
        if (cc) exp = ~ref_match(pp, aa);
        if (y !== exp) begin
            $display("Mismatch [%s]: c=%b p=%b a=%b -> got %b exp %b",
                     tag, c, p, a, y, exp);
            errors++;
        end
    endtask

    logic [31:0] r;
    initial begin
        errors = 0;

        step(1'b1, 4'd0, match_addr(0), "init");

        // 1. Transparent-mode directed: every threshold (incl. P>=12 aliases).
        for (int k = 0; k <= 15; k++) begin
            step(1'b1, k[3:0], match_addr(k),            $sformatf("k=%0d match", k));
            step(1'b1, k[3:0], match_addr(k) ^ 12'h001,  $sformatf("k=%0d flip1", k));
            step(1'b1, k[3:0], match_addr(k) ^ 12'h800,  $sformatf("k=%0d flip12", k));
        end

        // 2. Explicit hold sequences.
        step(1'b1, 4'd7, match_addr(7),  "hold:set0");   // y=0
        step(1'b0, 4'd7, match_addr(7),  "hold:latch");  // hold 0
        step(1'b0, 4'd7, 12'h000,        "hold:chgA");   // still 0
        step(1'b0, 4'd2, 12'hFFF,        "hold:chgP");   // still 0
        step(1'b1, 4'd2, 12'hFFF,        "hold:open");   // follow -> 1

        step(1'b1, 4'd3, match_addr(3),  "hold:set1");   // y=0
        step(1'b0, 4'd5, match_addr(4),  "hold:chg");    // mismatch underneath, held 0
        step(1'b1, 4'd5, match_addr(4),  "hold:open2");  // follow -> 1

        // 3. Random sequence with C toggling.
        r = $urandom(32'h0680_5678);
        for (int n = 0; n < 2000; n++) begin
            r = $urandom;
            step(r[0], r[5:2], r[17:6], $sformatf("rand %0d", n));
        end

        if (errors != 0) $fatal(1, "tb_ttl_74x680: %0d mismatches", errors);
        $display("PASS: tb_ttl_74x680 (directed + hold sequences + 2000 random)");
        $finish;
    end
endmodule
