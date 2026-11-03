// Dual-core differential fixture: both 6502 implementations with independent
// clocks and buses, so a C++ driver can step each to its next opcode fetch and
// compare architectural state.
`timescale 1ns/1ps
`default_nettype none
module dual_6502_top (
    input  logic        clk_a, rst_n_a,
    input  logic [7:0]  din_a,
    output logic [15:0] addr_a,
    output logic [7:0]  dout_a,
    output logic        we_a, fetch_a, fault_a,
    output logic [15:0] pc_a,
    output logic [7:0]  p_a, a_a, x_a, y_a, s_a,

    input  logic        clk_b, rst_n_b,
    input  logic [7:0]  din_b,
    output logic [15:0] addr_b,
    output logic [7:0]  dout_b,
    output logic        we_b, fetch_b, fault_b,
    output logic [15:0] pc_b,
    output logic [7:0]  p_b, a_b, x_b, y_b, s_b
);
    mos_6502 core_functional (
        .clk(clk_a), .rst_n(rst_n_a),
        .bus_addr(addr_a), .bus_data_i(din_a), .bus_data_o(dout_a), .bus_we(we_a),
        .irq_n(1'b1), .nmi_n(1'b1),
        .fetch_o(fetch_a), .fault_o(fault_a),
        .pc_o(pc_a), .status_o(p_a), .a_o(a_a), .x_o(x_a), .y_o(y_a), .s_o(s_a)
    );

    mos_6502_cycle core_cycle (
        .clk(clk_b), .rst_n(rst_n_b), .res_n(1'b1),
        .irq_n(1'b1), .nmi_n(1'b1), .rdy(1'b1), .so_n(1'b0),
        .bus_addr(addr_b), .bus_data_i(din_b), .bus_data_o(dout_b), .bus_we(we_b),
        .fetch_o(fetch_b), .fault_o(fault_b),
        .pc_o(pc_b), .status_o(p_b), .a_o(a_b), .x_o(x_b), .y_o(y_b), .sp_o(s_b)
    );
endmodule
`default_nettype wire
