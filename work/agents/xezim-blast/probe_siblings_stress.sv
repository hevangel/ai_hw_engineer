`timescale 1ns/1ps
// Stress harness for the 677/678/680 oracle shape, mirroring tb_ttl_74x679's
// 131072-vector sweep so the same code path is exercised at the same scale.
// NOT EXECUTED in the reporting session (no command-execution environment).
//
//   docker run --rm -v "B:\ai_hw_engineer:/workspace" -w /workspace \
//     ai-hw-engineer:latest sh -c \
//     'cd design/ttl_74xx && xezim --simulate --sv2017 --error-exit --max-time 100ms \
//        -s tb_xezim_blast_678 src/ttl_74x678.sv ../work/agents/xezim-blast/probe_siblings_stress.sv'
//
// Expected on a correct simulator: 0 diff, 0 x. Any x or stale return is the
// 679 signature; a wrong-but-legal 0/1 that still matches the DUT is the
// silent-masking case the strict compare cannot see.
module tb_xezim_blast_678;
    logic        c;
    logic [3:0]  p;
    logic [16:1] a;
    logic        y;
    int x_returns, mismatches;

    ttl_74x678 dut (.c(c), .p(p), .a(a), .y(y));

    // Structurally identical to tb_ttl_74x678's ref_match.
    function automatic logic ref_match(input logic [3:0] pp, input logic [16:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 16; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return m;
    endfunction

    logic exp;
    initial begin
        x_returns = 0;
        mismatches = 0;
        exp = 1'b0;
        for (int v = 0; v < (1 << 20); v++) begin
            {c, p, a} = v[20:0];
            #1;
            if (c) exp = ~ref_match(p, a);
            if ($isunknown(exp)) begin
                if (x_returns < 10)
                    $display("X v=%0d c=%b p=%0d a=%b", v, c, p, a);
                x_returns++;
            end else if (y !== exp) begin
                if (mismatches < 10)
                    $display("Mismatch v=%0d c=%b p=%0d a=%b -> got %b exp %b",
                             v, c, p, a, y, exp);
                mismatches++;
            end
        end
        $display("SUMMARY x_returns=%0d mismatches=%0d", x_returns, mismatches);
        if (x_returns != 0 || mismatches != 0) $fatal(1, "oracle unstable");
        $display("PASS: stress 74x678 oracle (1048576 vectors)");
        $finish;
    end
endmodule
