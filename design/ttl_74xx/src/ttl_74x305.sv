// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x305.md.
// ttl_74x305 - Octal ÷2 clock driver, 4 outputs inverted.
module ttl_74x305 (
    input  logic       clk,
    input  logic       clr_n,
    output logic [7:0] y      // y[3:0] non-inverted, y[7:4] inverted
);
    logic toggle;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) toggle <= 1'b0;
        else        toggle <= ~toggle;
    end
    assign y[3:0] = {4{toggle}};
    assign y[7:4] = {4{~toggle}};
endmodule
