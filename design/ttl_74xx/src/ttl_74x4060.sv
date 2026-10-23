// ASSUMPTION: external digital CLKI; no RC/crystal or ripple-delay model.
module ttl_74x4060 (
    input logic clki, clr,
    output logic [9:0] q,
    output logic clko, clko_n
);
    logic [13:0] count;
    always_ff @(negedge clki or posedge clr) begin
        if (clr) count<=14'b0;
        else count<=count+14'd1;
    end
    assign q={count[13:11],count[9:3]};
    assign clko=!clr && clki;
    assign clko_n=clr || !clki;
endmodule
