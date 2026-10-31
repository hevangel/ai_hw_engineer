`timescale 1ns/1ps
// ---------------------------------------------------------------------------
// v_ignoreargs.sv - axis 7: does the function break if it ignores its arguments?
//
// The function still takes all three arguments (so the call site and the
// argument marshalling are unchanged) but returns a constant and never reads
// them; there is no local state and no loop.
//
// This separates "argument aliasing / marshalling corruption" from "local state
// corruption". A constant-returning call that still goes wrong means the call
// mechanism itself is broken; a clean run means the loop or the locals are
// needed.
//
// Caveat: a compiler may fold an argument-independent function, in which case
// errors=0 proves nothing. Check with XEZIM_JIT_VERBOSE=1 / --profile.
//
// Expected if xezim were correct: "errors=0".
// ---------------------------------------------------------------------------
module v_ignoreargs;

    logic        g_n;
    logic [3:0]  p;
    logic [12:1] a;

    int          errors;
    logic        got;

    function automatic logic ref_const(input logic gn, input logic [3:0] pp,
                                       input logic [12:1] aa);
        return 1'b1;
    endfunction

    initial begin
        errors = 0;
        for (int v = 0; v < 131072; v++) begin
            {g_n, p, a} = v[16:0];
            got = ref_const(g_n, p, a);
            if (got !== 1'b1) begin
                if (errors < 10)
                    $display("Mismatch v=%0d: g_n=%b p=%0d a=%b -> got %b exp 1",
                             v, g_n, p, a, got);
                errors++;
            end
        end
        $display("errors=%0d", errors);
        $finish;
    end
endmodule
