// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4102.md.
// ttl_74x4102 - 2-digit BCD presettable synchronous down counter.
// Two BCD digits (8 bits) with sync parallel load, count enable, and
// terminal-count output that pulses when both digits are 0.
module ttl_74x4102 (
    input  logic       clk, rst,
    input  logic       load_n, ce_n,
    input  logic [7:0] d,             // d[7:4]=tens, d[3:0]=ones
    output logic [7:0] q,
    output logic       tc_n
);
    logic [3:0] ones, tens;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ones <= 4'd0; tens <= 4'd0;
        end else if (!load_n) begin
            ones <= d[3:0]; tens <= d[7:4];
        end else if (!ce_n) begin
            if (ones != 4'd0) ones <= ones - 4'd1;
            else begin
                ones <= 4'd9;
                if (tens != 4'd0) tens <= tens - 4'd1;
                else              tens <= 4'd9;
            end
        end
    end

    assign q    = {tens, ones};
    assign tc_n = ~(ones == 4'd0 && tens == 4'd0);
endmodule
