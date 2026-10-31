// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x8161.md.
// ttl_74x8161 - 8-bit synchronous binary counter with sync clear, sync load.
module ttl_74x8161 (
    input  logic       clk, clr_n, load_n, en_p, en_t,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       rco
);
    always_ff @(posedge clk) begin
        if (!clr_n)       q <= 8'd0;
        else if (!load_n) q <= d;
        else if (en_p && en_t) q <= q + 8'd1;
    end
    assign rco = en_t && (q == 8'hFF);
endmodule
