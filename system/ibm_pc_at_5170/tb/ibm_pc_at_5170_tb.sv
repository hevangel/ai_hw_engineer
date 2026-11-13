// Simulation wrapper: the system board plus verification-only taps of the
// CPU's retirement state and read data. The taps use hierarchical
// references, so this wrapper is not synthesized.
module ibm_pc_at_5170_tb (
    input  logic        clk_i, clk_2x_i, reset_i, ready_n_i,
    input  logic        dma_clk_n_i, hold_permit_i, refresh_ready_i,
    input  logic [2:0]  timer_clk_i,
    input  logic [15:0] mem_rdata_i,
    output logic [23:0] address_o,
    output logic [15:0] data_o, cpu_data_o,
    output logic        data_oe_o, address_oe_o, bhe_n_o, io_cycle_o, fetch_cycle_o,
    output logic [1:0]  completed_bytes_o,
    output logic        hlda_o, cycle_active_o, protocol_error_o,
    output logic        halted_o, shutdown_o, fault_o,
    output logic        refresh_o, refresh_ras_trigger_o,
    output logic        refresh_memr_n_o, refresh_memr_oe_o,
    output logic        io_unclaimed_o, io_read_undriven_o,
    output logic [7:0]  post_code_o,
    output logic        retire_o,
    output logic [23:0] retire_pc_o,
    output logic [7:0]  retire_opcode_o,
    output logic [127:0] regs_o,
    output logic [63:0] segs_o,
    output logic [15:0] ip_o, flags_o
);
    /* verilator lint_off PINMISSING */
    ibm_pc_at_5170 board (
        .clk_i, .clk_2x_i, .reset_i, .ready_n_i, .dma_clk_n_i, .hold_permit_i,
        .refresh_ready_i, .timer_clk_i, .mem_rdata_i, .address_o, .data_o,
        .data_oe_o, .address_oe_o, .bhe_n_o, .io_cycle_o, .fetch_cycle_o, .completed_bytes_o, .hlda_o,
        .cycle_active_o, .protocol_error_o, .halted_o, .shutdown_o, .fault_o,
        .refresh_o, .refresh_ras_trigger_o, .refresh_memr_n_o, .refresh_memr_oe_o,
        .io_unclaimed_o, .io_read_undriven_o, .post_code_o
    );
    /* verilator lint_on PINMISSING */
    assign cpu_data_o = board.core.cpu_data;
    assign retire_o = board.core.native.cpu.core.retire_o;
    assign retire_pc_o = board.core.native.cpu.core.retire_pc_o;
    assign retire_opcode_o = board.core.native.cpu.core.retire_opcode_o;
    assign regs_o = board.core.native.cpu.core.regs_o;
    assign segs_o = board.core.native.cpu.core.segs_o;
    assign ip_o = board.core.native.cpu.core.ip_o;
    assign flags_o = board.core.native.cpu.core.flags_o;
endmodule
