`timescale 1ns/1ps
// Diagnostic probe: does calling ref_y repeatedly (as the real TB does)
// change its result versus calling it once in isolation?
module probe_679_loop;
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

    initial begin
        for (int v = 0; v < 8192; v++) begin
            {g_n, p, a} = v[16:0];
            #1;
            if (v == 4090 || v == 4094 || v == 4095 || v == 8188)
                $display("loop v=%0d p=%b a=%b ref=%b y=%b", v, p, a,
                         ref_y(g_n, p, a), y);
        end
        // Same vector again, outside the loop.
        $display("after loop v=4094 ref=%b", ref_y(1'b0, 4'b0000, 12'b111111111110));
        $finish;
    end
endmodule
