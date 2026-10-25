// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x304.md.
// ttl_74x304 - Octal ÷2 clock driver (all outputs in-phase).
module ttl_74x304 (
    input  logic       clk,
    input  logic       clr_n,
    output logic [7:0] y
);
    logic toggle;
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n) toggle <= 1'b0;
        else        toggle <= ~toggle;
    end
    assign y = {8{toggle}};
endmodule
