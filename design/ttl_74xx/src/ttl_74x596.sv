// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x596.md.
// ttl_74x596 - 8-bit shift register, output latches, open-collector outputs (digital model).
module ttl_74x596 (
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
