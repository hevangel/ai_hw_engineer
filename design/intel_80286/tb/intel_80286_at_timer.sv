// Verification fixture for the canonical IBM AT timer ports. The fixture
// clock and counter clocks are supplied by the caller; no native timing is
// implied by the 80286 core's transaction-level clock.
module intel_80286_at_timer (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        io_req_i,
    input  logic        io_ready_i,
    input  logic        io_write_i,
    input  logic [15:0] io_addr_i,
    input  logic [7:0]  io_wdata_i,
    input  logic        port61_bit0_i,
    input  logic [2:0]  counter_clk_i,
    output logic        selected_o,
    output logic        rdata_valid_o,
    output logic [7:0]  rdata_o,
    output logic [2:0]  timer_out_o
);
    logic accepted;

    // Restrict this fixture to the BIOS's four canonical timer ports. Other
    // address aliases require board-decode evidence before they are modeled.
    assign selected_o = io_req_i && io_addr_i[15:2] == 14'h0010;
    assign accepted = selected_o && io_ready_i;

    intel_8253_8254 #(.IS_8254(1'b1)) timer (
        .clk(clk), .rst_n(rst_n),
        .cs_n(!accepted), .rd_n(!(accepted && !io_write_i)),
        .wr_n(!(accepted && io_write_i)), .addr(io_addr_i[1:0]),
        .data_i(io_wdata_i), .data_o(rdata_o), .data_oe(rdata_valid_o),
        .counter_clk_i(counter_clk_i), .gate_i({port61_bit0_i, 2'b11}),
        .out_o(timer_out_o)
    );
endmodule
