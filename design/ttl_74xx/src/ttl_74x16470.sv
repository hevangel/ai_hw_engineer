// ASSUMPTION: valid setup/hold; do not lower CLKEN_N while CLK is high.
module ttl_74x16470 (
    input logic [15:0] a_in, b_in,
    input logic [1:0] clk_ab, clk_ba,
    input logic [1:0] clken_ab_n, clken_ba_n,
    input logic [1:0] oe_ab_n, oe_ba_n,
    output logic [15:0] a_out, b_out,
    output logic [1:0] a_drive, b_drive
);
    for (genvar bank=0; bank<2; bank++) begin : banks
        logic [7:0] ab, ba;
        logic capture_ab, capture_ba;
        assign capture_ab=clk_ab[bank] && !clken_ab_n[bank];
        assign capture_ba=clk_ba[bank] && !clken_ba_n[bank];
        always_ff @(posedge capture_ab) ab<=a_in[bank*8+:8];
        always_ff @(posedge capture_ba) ba<=b_in[bank*8+:8];
        assign a_drive[bank]=!clken_ba_n[bank] && !oe_ba_n[bank];
        assign b_drive[bank]=!clken_ab_n[bank] && !oe_ab_n[bank];
        assign a_out[bank*8+:8]=a_drive[bank] ? ba : 8'b0;
        assign b_out[bank*8+:8]=b_drive[bank] ? ab : 8'b0;
    end
endmodule
