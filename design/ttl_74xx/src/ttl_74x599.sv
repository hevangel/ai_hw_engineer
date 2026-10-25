// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x599.md.
// ttl_74x599 - 8-bit shift register with output latches, open-collector outputs (digital model).
module ttl_74x599 (
    input  logic       clk_shift, srclr_n,
    input  logic       clk_lat, oe_n,
    input  logic       sin,
    output logic [7:0] q
);
    logic [7:0] shifter, outreg;
    always_ff @(posedge clk_shift or negedge srclr_n) begin
        if (!srclr_n) shifter <= 0;
        else          shifter <= {shifter[6:0], sin};
    end
    always_ff @(posedge clk_lat) outreg <= shifter;
    assign q = oe_n ? 8'hff : outreg;
endmodule
