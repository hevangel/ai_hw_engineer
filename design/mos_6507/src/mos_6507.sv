// MOS 6507 sampled package adapter; see spec/spec.md for clock/debug limits.
module mos_6507 (
    input  logic clk, rst_n, rdy_i,
    output logic [12:0] bus_addr,
    input  logic [7:0] bus_data_i,
    output logic [7:0] bus_data_o,
    output logic bus_we, fetch_o, fault_o, jammed_o,
    output logic [15:0] debug_bus_addr_o, pc_o,
    output logic [7:0] status_o, a_o, x_o, y_o, s_o
);
    // Visual6502's die photograph establishes the IRQ/NMI metal ties.
    // ASSUMPTION: absent SO is inactive; the package has no external SO.
    mos_6502_native #(.DECIMAL_ENABLE(1)) core (
        .clk, .rst_n, .rdy_i, .irq_n(1'b1), .nmi_n(1'b1), .so_n(1'b1),
        .bus_addr(debug_bus_addr_o), .bus_data_i, .bus_data_o, .bus_we,
        .fetch_o, .fault_o, .jammed_o, .pc_o, .status_o, .a_o, .x_o, .y_o, .s_o
    );
    assign bus_addr = debug_bus_addr_o[12:0];
`ifdef FORMAL
    `include "mos_6507_props.sv"
`endif
endmodule
