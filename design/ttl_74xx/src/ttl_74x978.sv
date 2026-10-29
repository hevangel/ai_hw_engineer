// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x978.md.
// ttl_74x978 - octal D-type flip-flop with serial scanner.
// Acts as a normal octal D-FF in functional mode (test_n=1) and as an 8-bit
// scan shift register in test mode (test_n=0), with scan_in -> q[0] -> q[1]
// -> ... -> q[7] -> scan_out.
module ttl_74x978 (
    input  logic       clk,
    input  logic       clr_n,
    input  logic       oe_n,
    input  logic       test_n,    // 1 = parallel load, 0 = scan shift
    input  logic       scan_in,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       scan_out,
    output logic       hiz
);
    logic [7:0] reg_q;

    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)       reg_q <= 8'b0;
        else if (test_n)  reg_q <= d;
        else              reg_q <= {reg_q[6:0], scan_in};
    end

    assign q        = oe_n ? 8'b0 : reg_q;
    assign scan_out = reg_q[7];
    assign hiz      = oe_n;
endmodule
