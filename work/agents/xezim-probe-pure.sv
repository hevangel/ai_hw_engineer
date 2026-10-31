`timescale 1ns/1ps
// Same body, two variants: one pure (no side effects), one with a system task.
// Called with a variable actual so nothing folds at compile time.
module probe_pure;
    logic [11:0] b;

    // pure: returns the bit directly
    function automatic logic pure_bit(input logic [12:1] a); return a[1]; endfunction

    // impure: same read, plus a side effect that cannot be folded away
    function automatic logic impure_bit(input logic [12:1] a);
        $display("      [impure_bit] a=%b a[1]=%b", a, a[1]);
        return a[1];
    endfunction

    initial begin
        b = 12'b000000000001;          // bit 0 set -> a[1] must be 1
        $display("pure_bit   = %b (expect 1)", pure_bit(b));
        $display("impure_bit = %b (expect 1)", impure_bit(b));

        b = 12'b000000000000;          // nothing set -> a[1] must be 0
        $display("pure_bit   = %b (expect 0)", pure_bit(b));
        $display("impure_bit = %b (expect 0)", impure_bit(b));

        b = 12'b100000000000;          // only top bit -> a[1] must be 0
        $display("pure_bit   = %b (expect 0)", pure_bit(b));
        $display("impure_bit = %b (expect 0)", impure_bit(b));
        $finish;
    end
endmodule
