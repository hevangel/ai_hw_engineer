// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x484.md.
// ttl_74x484 - BCD-to-binary converter (same as 74x184).
module ttl_74x484 (
    input  logic [7:0] bcd,
    output logic [5:0] bin
);
    logic [3:0] hi, lo;
    always_comb begin
        hi = bcd[7:4];
        lo = bcd[3:0];
        if (hi < 10 && lo < 10) bin = 6'(hi * 10 + lo);
        else                    bin = 0;
    end
endmodule
