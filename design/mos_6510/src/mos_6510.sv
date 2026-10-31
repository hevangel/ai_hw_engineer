module mos_6510 #(
    parameter int unsigned PORT_FALLOFF_CYCLES = 350000
) (
    input logic clk, rst_n, rdy_i, irq_n, nmi_n, aec_i,
    output logic [15:0] bus_addr,
    input logic [7:0] bus_data_i,
    output logic [7:0] bus_data_o,
    output logic bus_we, bus_addr_oe, bus_rw_oe, bus_data_oe,
    input logic [5:0] port_i,
    output logic [5:0] port_o, port_oe,
    output logic [7:0] ddr_o, latch_o,
    output logic fetch_o, fault_o, jammed_o,
    output logic [15:0] pc_o,
    output logic [7:0] status_o, a_o, x_o, y_o, s_o
);
    logic internal_port;
    logic [7:0] core_data_i, port_data;
    assign internal_port = bus_addr[15:1] == 0;
    assign core_data_i = internal_port ? port_data : bus_data_i;
    assign bus_addr_oe = aec_i;
    assign bus_rw_oe = aec_i;
    // Port writes update the internal latch but do not drive CPU data onto
    // the external RAM bus. The board resolves its remaining bus drivers.
    assign bus_data_oe = aec_i && bus_we && !internal_port;
    // AEC is a driver control, not an additional RDY/stall signal.
    // ASSUMPTION: absent SO is inactive; see spec/spec.md.
    mos_6502_native core (
        .clk, .rst_n, .rdy_i, .irq_n, .nmi_n, .so_n(1'b1),
        .bus_addr, .bus_data_i(core_data_i), .bus_data_o, .bus_we,
        .fetch_o, .fault_o, .jammed_o, .pc_o, .status_o, .a_o, .x_o, .y_o, .s_o
    );
    mos_6510_port #(.PORT_FALLOFF_CYCLES(PORT_FALLOFF_CYCLES)) port_block (
        .clk, .rst_n, .write_i(bus_we && internal_port), .address_i(bus_addr[0]),
        .data_i(bus_data_o), .port_i, .data_o(port_data), .ddr_o, .latch_o, .port_o, .port_oe
    );
`ifdef FORMAL
    `include "mos_6510_props.sv"
`endif
endmodule
