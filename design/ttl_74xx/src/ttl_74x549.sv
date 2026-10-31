// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x549.md.
// ttl_74x549 - 8-bit two-stage pipelined latch.
module ttl_74x549 (
    input  logic       le1, le2, clr_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    logic [7:0] s1;
    always_latch begin
        if (!clr_n)    s1 = 0;
        else if (le1)  s1 = d;
    end
    always_latch begin
        if (!clr_n)    q = 0;
        else if (le2)  q = s1;
    end
endmodule
