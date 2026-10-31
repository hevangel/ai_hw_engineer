// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1403.md.
// ttl_74x1403 - 8-bit bus receiver plus 4-bit bus driver.
// Two independent registered sections sharing a package: an 8-bit input
// receiver (registers 8 bus signals on rx_clk) and a 4-bit output driver
// (registers 4 internal signals on tx_clk and drives them out 3-state).
module ttl_74x1403 (
    // 8-bit bus receiver
    input  logic       rx_clk,
    input  logic       rx_oe_n,
    input  logic [7:0] bus_in,
    output logic [7:0] rx_out,
    output logic       rx_hiz,
    // 4-bit bus driver
    input  logic       tx_clk,
    input  logic       tx_oe_n,
    input  logic [3:0] tx_in,
    output logic [3:0] bus_out,
    output logic       tx_hiz
);
    logic [7:0] rx_reg;
    logic [3:0] tx_reg;

    always_ff @(posedge rx_clk) rx_reg <= bus_in;
    always_ff @(posedge tx_clk) tx_reg <= tx_in;

    assign rx_out  = rx_oe_n ? 8'b0 : rx_reg;
    assign rx_hiz  = rx_oe_n;
    assign bus_out = tx_oe_n ? 4'b0 : tx_reg;
    assign tx_hiz  = tx_oe_n;
endmodule
