// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x469.md.
// ttl_74x469 - 8-bit synchronous up/down counter with parallel load and hold.
module ttl_74x469 (
    input  logic       clk, load_n, u_d_n, ce_n,
    input  logic [7:0] d,
    output logic [7:0] q
);
    always_ff @(posedge clk) begin
        if (!load_n)         q <= d;
        else if (!ce_n) begin
            if (!u_d_n) q <= q + 1;
            else        q <= q - 1;
        end
    end
endmodule
