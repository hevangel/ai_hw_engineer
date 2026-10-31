`timescale 1ns/1ps
// Diagnostic probe for the ttl_74x679 reference model. Not part of the design.
module probe_679;
    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;
    logic        y;

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

    task automatic show(input int v);
        {g_n, p, a} = v[16:0];
        #1;
        $display("v=%0d g_n=%b p=%b a=%b y=%b ref=%b intcast=%0d",
                 v, g_n, p, a, y, ref_y(g_n, p, a), int'(p));
    endtask

    initial begin
        show(0);
        show(4094);
        show(4095);
        show(8188);
        show(8189);
        show(8190);
        show(8191);
        show(12280);
        show(45056);
        show(61441);
        $finish;
    end
endmodule
