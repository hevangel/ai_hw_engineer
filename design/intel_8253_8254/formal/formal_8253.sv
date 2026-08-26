module formal_8253 (
    input logic       clk,
    input logic       rst_n,
    input logic       cs_n,
    input logic       rd_n,
    input logic       wr_n,
    input logic [1:0] addr,
    input logic [7:0] data_i,
    input logic [2:0] counter_clk_i,
    input logic [2:0] gate_i
);

    logic [7:0] data_o;
    logic       data_oe;
    logic [2:0] out_o;

    intel_8253_8254 #(
        .IS_8254 (1'b0)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .cs_n          (cs_n),
        .rd_n          (rd_n),
        .wr_n          (wr_n),
        .addr          (addr),
        .data_i        (data_i),
        .data_o        (data_o),
        .data_oe       (data_oe),
        .counter_clk_i (counter_clk_i),
        .gate_i        (gate_i),
        .out_o         (out_o)
    );

    intel_8253_8254_props #(
        .IS_8254 (1'b0)
    ) properties (
        .clk     (clk),
        .rst_n   (rst_n),
        .cs_n    (cs_n),
        .rd_n    (rd_n),
        .wr_n    (wr_n),
        .addr    (addr),
        .data_i  (data_i),
        .data_o  (data_o),
        .data_oe (data_oe),
        .out_o   (out_o)
    );

endmodule
