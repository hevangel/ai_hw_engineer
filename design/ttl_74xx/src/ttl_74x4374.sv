// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x4374.md.
// ttl_74x4374 - 8-bit dual-rank synchronizer.
// Two cascaded clocked registers to reduce metastability when sampling
// asynchronous inputs. Output = second stage.
module ttl_74x4374 (
    input  logic       clk, oe_n,
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       hiz
);
    logic [7:0] s1, s2;
    always_ff @(posedge clk) begin
        s1 <= d;
        s2 <= s1;
    end
    assign q   = oe_n ? 8'b0 : s2;
    assign hiz = oe_n;
endmodule
