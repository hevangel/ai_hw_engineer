`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_static.sv - axis 3: is `automatic` required?
//
// Only change from minimal_fail.sv: `function logic ref_y` (default static).
// A static function has one frame for the whole simulation, so if the bug is
// "the frame is reallocated/reused per call", this variant should behave
// differently.
//
// errors=0  -> `automatic` is required (default-state corruption).
// errors>0  -> the call frame is not the trigger; look at the port/loop shape.
// ---------------------------------------------------------------------------
module v_static;

    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;

    int          errors;
    logic [11:0] b;
    logic [11:0] low;
    int          k;
    logic        got;
    logic        gold;

    function logic ref_y(input logic gn, input logic [3:0] pp,
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
        for (int v = 0; v < 131072; v++) begin
            {g_n, p, a} = v[16:0];
            got  = ref_y(g_n, p, a);
            b    = a;
            k    = p;
            low  = (k >= 12) ? 12'hFFF : ((12'h001 << k) - 12'h001);
            gold = g_n ? 1'b1
                       : ~(((b & low) == 12'h000) &&
                           ((b & ~low) == (12'hFFF & ~low)));
            if (got !== gold) begin
                if (errors < 10)
                    $display("Mismatch v=%0d: g_n=%b p=%0d a=%b -> got %b exp %b",
                             v, g_n, k, a, got, gold);
                errors++;
            end
        end
        $display("errors=%0d", errors);
        $finish;
    end
endmodule
