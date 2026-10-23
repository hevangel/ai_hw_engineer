// ASSUMPTION: valid powered logic; analog timing and drive are omitted.
module ttl_74x2525 (
    input logic clock_in,
    output logic [7:0] q
);
    assign q={8{clock_in}};
endmodule
