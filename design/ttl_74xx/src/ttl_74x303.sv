// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x303.md.
// ttl_74x303 - Octal ÷2 clock driver, 2 outputs inverted.
module ttl_74x303 (
    input  logic       clk,
    input  logic       clr_n,
    output logic [7:0] y      // y[0..5] non-inverted ÷2 of clk; y[6..7] inverted
);
    logic toggle;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) toggle <= 1'b0;
        else        toggle <= ~toggle;
    end
    assign y[5:0] = {6{toggle}};
    assign y[7:6] = {2{~toggle}};
endmodule
