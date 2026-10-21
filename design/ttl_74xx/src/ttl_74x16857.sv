// ASSUMPTION: clk represents a valid differential crossing; see part spec.
module ttl_74x16857 (
    input logic clk,rst_n,
    input logic [13:0] d,
    output logic [13:0] q
);
    logic [13:0] stored;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) stored<='0;
        else stored<=d;
    end
    assign q=stored;
endmodule
