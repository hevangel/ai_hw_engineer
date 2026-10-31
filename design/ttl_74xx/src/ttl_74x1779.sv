// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1779.md.
// ttl_74x1779 - 8-bit bidirectional binary counter.
// Synchronous up/down counter with parallel load and async clear.
module ttl_74x1779 (
    input  logic       clk,
    input  logic       clr_n,        // async clear, active low
    input  logic       load_n,       // sync parallel load, active low
    input  logic       cnt_en_n,     // count enable, active low
    input  logic       up_dn,        // 1 = up, 0 = down
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       rco_n         // ripple carry out, active low
);
    always_ff @(posedge clk or negedge clr_n) begin
        if (!clr_n)        q <= 8'h00;
        else if (!load_n)  q <= d;
        else if (!cnt_en_n) q <= up_dn ? (q + 8'd1) : (q - 8'd1);
    end

    assign rco_n = ~(!cnt_en_n &&
                     (( up_dn && q == 8'hFF) ||
                      (!up_dn && q == 8'h00)));
endmodule
