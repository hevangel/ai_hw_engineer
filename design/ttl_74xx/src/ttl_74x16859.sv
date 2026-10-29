// ASSUMPTION: clk represents a valid differential crossing; see part spec.
module ttl_74x16859 (
    input logic clk,rst_n,
    input logic [12:0] d,
    output logic [12:0] q_a,q_b
);
    logic [12:0] stored;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) stored<='0;
        else stored<=d;
    end
    assign q_a=stored;
    assign q_b=stored;
endmodule
