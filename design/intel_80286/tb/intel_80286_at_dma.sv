// Register-only DMA fixture. Bus mastering, cascade, refresh and page
// registers are deliberately outside this adapter's present scope.
module intel_80286_at_dma (
    input  logic        clk, rst_n,
    input  logic        io_req_i, io_ready_i, io_write_i,
    input  logic [15:0] io_addr_i,
    input  logic [7:0]  io_wdata_i,
    output logic        selected_o, controller2_o, rdata_valid_o,
    output logic [7:0]  rdata_o
);
    logic select1, select2, accepted1, accepted2;
    logic [7:0] data1, data2;
    logic oe1, oe2;

    // Canonical controller-1 ports 00h–0Fh and controller-2 even ports
    // C0h–DEh. Other decoded aliases are not modeled by this fixture.
    assign select1 = io_req_i && io_addr_i[15:4] == 12'h000;
    assign select2 = io_req_i && io_addr_i[15:5] == 11'h006 && !io_addr_i[0];
    assign selected_o = select1 || select2;
    assign controller2_o = select2;
    assign accepted1 = select1 && io_ready_i;
    assign accepted2 = select2 && io_ready_i;
    assign rdata_valid_o = oe1 || oe2;
    assign rdata_o = oe1 ? data1 : data2;

    /* verilator lint_off PINMISSING */
    intel_8237 controller1 (
        .clk(clk), .rst_n(rst_n), .cs_n(!accepted1),
        .ior_n(!(accepted1 && !io_write_i)), .iow_n(!(accepted1 && io_write_i)),
        .reg_addr(io_addr_i[3:0]), .data_i(io_wdata_i),
        .data_o(data1), .data_oe(oe1), .dreq(4'b0000),
        .hlda(1'b0), .ready(1'b1), .eop_n(1'b1)
    );
    intel_8237 controller2 (
        .clk(clk), .rst_n(rst_n), .cs_n(!accepted2),
        .ior_n(!(accepted2 && !io_write_i)), .iow_n(!(accepted2 && io_write_i)),
        .reg_addr(io_addr_i[4:1]), .data_i(io_wdata_i),
        .data_o(data2), .data_oe(oe2), .dreq(4'b0000),
        .hlda(1'b0), .ready(1'b1), .eop_n(1'b1)
    );
    /* verilator lint_on PINMISSING */
endmodule
