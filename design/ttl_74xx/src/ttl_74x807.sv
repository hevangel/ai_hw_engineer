// ASSUMPTION: valid powered logic; analog timing and drive are omitted.
module ttl_74x807 (
    input logic clock_in,
    output logic [9:0] q
);
    assign q={10{clock_in}};
endmodule
