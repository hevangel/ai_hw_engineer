// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x589.md.
// ttl_74x589 - 8-bit shift register with input latch and serial output (3-state qh).
module ttl_74x589 (
    input  logic       clk_lat, le_n, // load parallel latch on clk_lat rising when le_n=0
    input  logic       clk_shift,     // shift on rising edge
    input  logic       shift_load_n,  // 0 = load latch into shifter, 1 = shift
    input  logic       oe_n, sin,
    input  logic [7:0] d,
    output logic       qh,
    output logic       hiz
);
    logic [7:0] latch_r, shifter;
    always_ff @(posedge clk_lat) if (!le_n) latch_r <= d;
    always_ff @(posedge clk_shift) begin
        if (!shift_load_n) shifter <= latch_r;
        else               shifter <= {shifter[6:0], sin};
    end
    assign qh  = oe_n ? 1'b0 : shifter[7];
    assign hiz = oe_n;
endmodule
