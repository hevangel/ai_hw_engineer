// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x485.md.
// ttl_74x485 - Binary-to-BCD converter (same as 74x185).
module ttl_74x485 (
    input  logic [5:0] bin,
    output logic [7:0] bcd
);
    logic [3:0] hi, lo;
    always_comb begin
        hi = 4'(bin / 10);
        lo = 4'(bin % 10);
        bcd = {hi, lo};
    end
endmodule
