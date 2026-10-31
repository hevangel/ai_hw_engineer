`timescale 1ns/1ps
// Diagnostic probe: mirror the real TB's check construct exactly.
module probe_679_cmp;
    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;
    logic        y;
    int errors;

    ttl_74x679 dut (.g_n(g_n), .p(p), .a(a), .y(y));

    function automatic logic ref_y(input logic gn, input logic [3:0] pp,
                                   input logic [12:1] aa);
        logic m;
        m = 1'b1;
        for (int i = 1; i <= 12; i++)
            if (i <= int'(pp)) m &= (aa[i] == 1'b0);
            else               m &= (aa[i] == 1'b1);
        return gn ? 1'b1 : ~m;
    endfunction

    initial begin
        errors = 0;
        for (int v = 4090; v < 4100; v++) begin
            {g_n, p, a} = v[16:0];
            #1;
            if (y !== ref_y(g_n, p, a)) begin
                $display("Mismatch v=%0d: g_n=%b p=%b a=%b -> got %b exp %b",
                         v, g_n, p, a, y, ref_y(g_n, p, a));
                errors++;
            end else begin
                $display("ok       v=%0d p=%b a=%b y=%b ref=%b",
                         v, p, a, y, ref_y(g_n, p, a));
            end
        end
        $display("errors=%0d", errors);
        $finish;
    end
endmodule
