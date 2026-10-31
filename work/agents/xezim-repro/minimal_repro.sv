`timescale 1ns/1ps
// Minimal xezim 0.11.3 miscompilation reproducer.
//
// Two functions implement the same 12-bit address-comparator rule. They are
// exhaustively compared against each other over the whole 16-bit input space.
// `ref_direct` takes the address as a [12:1] formal and indexes it with a loop
// variable; `ref_mask` copies it into a [11:0] local and tests it with a mask.
//
// Expected on a conforming simulator: 0 mismatches.
// Observed on xezim 0.11.3 (git 058f2bba): 43 mismatches, most reporting x.
//
// Run:
//   xezim --simulate --sv2017 -s minimal_repro --max-time 500ms minimal_repro.sv

module minimal_repro;
    // non-zero-based packed formal, variable bit-select inside a loop
    function automatic logic ref_direct(input logic [3:0] p, input logic [12:1] a);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= p) m &= (a[i] == 1'b0);
            else        m &= (a[i] == 1'b1);
        return ~m;
    endfunction

    // same rule, zero-based local, no non-zero-based select
    function automatic logic ref_mask(input logic [3:0] p, input logic [11:0] b);
        logic [11:0] low;
        low = (p >= 12) ? 12'hFFF : ((12'h001 << p) - 12'h001);
        return ~(((b & low) == 12'h000) && ((b & ~low) == (12'hFFF & ~low)));
    endfunction

    int errors = 0;
    int shown  = 0;

    initial begin
        for (int v = 0; v < (1 << 16); v++) begin
            logic [3:0]  p;
            logic [12:1] a;
            logic        got, want;
            {p, a} = v[15:0];
            got  = ref_direct(p, a);
            want = ref_mask(p, a);
            if (got !== want) begin
                errors++;
                if (shown < 5) begin
                    $display("MISMATCH p=%0d a=%b got=%b want=%b", p, a, got, want);
                    shown++;
                end
            end
        end
        $display("minimal_repro: %0d mismatches over 65536 vectors", errors);
        if (errors != 0) $fatal(1, "xezim miscompiled the [12:1] formal bit-select");
        $finish;
    end
endmodule
