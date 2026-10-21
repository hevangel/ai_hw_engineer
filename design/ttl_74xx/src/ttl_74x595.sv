// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x595.md.
// ttl_74x595 - 8-bit shift register with output latch and 3-state outputs.
module ttl_74x595 (
    input  logic       clk_shift, srclr_n,
    input  logic       clk_lat, oe_n,
    input  logic       sin,
    output logic [7:0] q,
    output logic       qh_prime,
    output logic       hiz
);
    logic [7:0] shifter, outreg;
    always_ff @(posedge clk_shift or negedge srclr_n) begin
        if (!srclr_n) shifter <= 0;
        else          shifter <= {shifter[6:0], sin};
    end
    always_ff @(posedge clk_lat) outreg <= shifter;
    assign q        = oe_n ? 8'b0 : outreg;
    assign qh_prime = shifter[7];
    assign hiz      = oe_n;
endmodule
