// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2726.md.
// ttl_74x2726 - 4608-bit bidirectional FIFO memory (2x256x9).
// Same dual-queue structure as ttl_74x2235, with each direction sized to
// 256 deep x 9 bits (total 256*9*2 = 4608 bits).
module ttl_74x2726 (
    input  logic       rst_n,
    input  logic       wclk_ab, wr_n_ab,
    input  logic [8:0] din_ab,
    input  logic       rclk_ab, rd_n_ab,
    output logic [8:0] dout_ab,
    output logic       ef_n_ab, ff_n_ab,
    input  logic       wclk_ba, wr_n_ba,
    input  logic [8:0] din_ba,
    input  logic       rclk_ba, rd_n_ba,
    output logic [8:0] dout_ba,
    output logic       ef_n_ba, ff_n_ba
);
    localparam int DEPTH = 256;
    localparam int AW    = 8;

    logic [8:0]  mem_ab [0:DEPTH-1];
    logic [AW:0] wp_ab, rp_ab;
    logic [8:0]  mem_ba [0:DEPTH-1];
    logic [AW:0] wp_ba, rp_ba;

    wire empty_ab = (wp_ab == rp_ab);
    wire full_ab  = ((wp_ab - rp_ab) == (AW+1)'(DEPTH));
    wire empty_ba = (wp_ba == rp_ba);
    wire full_ba  = ((wp_ba - rp_ba) == (AW+1)'(DEPTH));

    always_ff @(posedge wclk_ab or negedge rst_n)
        if (!rst_n) wp_ab <= '0;
        else if (!wr_n_ab && !full_ab) begin
            mem_ab[wp_ab[AW-1:0]] <= din_ab;
            wp_ab <= wp_ab + 1;
        end
    always_ff @(posedge rclk_ab or negedge rst_n)
        if (!rst_n) rp_ab <= '0;
        else if (!rd_n_ab && !empty_ab) rp_ab <= rp_ab + 1;
    always_ff @(posedge wclk_ba or negedge rst_n)
        if (!rst_n) wp_ba <= '0;
        else if (!wr_n_ba && !full_ba) begin
            mem_ba[wp_ba[AW-1:0]] <= din_ba;
            wp_ba <= wp_ba + 1;
        end
    always_ff @(posedge rclk_ba or negedge rst_n)
        if (!rst_n) rp_ba <= '0;
        else if (!rd_n_ba && !empty_ba) rp_ba <= rp_ba + 1;

    assign dout_ab = mem_ab[rp_ab[AW-1:0]];
    assign dout_ba = mem_ba[rp_ba[AW-1:0]];
    assign ef_n_ab = ~empty_ab;
    assign ff_n_ab = ~full_ab;
    assign ef_n_ba = ~empty_ba;
    assign ff_n_ba = ~full_ba;
endmodule
