// Connect the functional 80286 core's native-beat boundary to the local-bus
// cycle controller and a separate M82288/M82C288 local-bus model. clk_i is
// the processor clock; clk_2x_i is the external system CLK at twice that rate.
module intel_80286_native_cpu #(
    parameter int RES_SYNC_DELAY_CLKS = 2
) (
    input  logic        clk_i,
    input  logic        clk_2x_i,
    input  logic        reset_i,       // optional already-conditioned active-high RESET
    input  logic        res_n_i,       // active-low 82C284 RES; tie high when unused
    input  logic        ready_n_i,
    input  logic        cenl_i,
    input  logic        cen_i,
    input  logic        cmdly_i,
    input  logic        hold_i,
    input  logic        intr_i,
    input  logic        nmi_i,
    input  logic        busy_i,
    input  logic        error_n_i,
    input  logic [15:0] data_i,

    output logic [15:0] data_o,
    output logic        data_oe_o,
    output logic [23:0] address_o,
    output logic        address_oe_o,
    output logic        bhe_n_o,
    output logic        cod_inta_o,
    output logic        m_io_o,
    output logic        s1_o,
    output logic        s0_o,
    output logic        status_oe_o,
    output logic        lock_n_o,
    output logic        lock_oe_o,
    output logic        hlda_o,
    output logic        cycle_active_o,
    output logic        protocol_error_o,
    output logic        ale_o,
    output logic        den_o,
    output logic        dt_r_o,
    output logic        mrdc_n_o,
    output logic        mwtc_n_o,
    output logic        iorc_n_o,
    output logic        iowc_n_o,
    output logic        inta_n_o,
    output logic        mce_o,
    output logic [1:0]  completed_bytes_o,
    output logic        halted_o,
    output logic        shutdown_o,
    output logic        fault_o,
    output logic [1:0]  fault_code_o,
    output logic        cpu_reset_o
);
    logic reset_from_res;
    logic cpu_reset;

    logic core_ready;
    logic [15:0] core_read_data;
    logic core_lock;
    logic inta_request;
    logic inta_ready;
    logic [7:0] inta_vector;
    logic bus_request, bus_halt_cycle, bus_shutdown_cycle;
    logic [23:0] bus_address;
    logic bus_fetch, bus_write, bus_io;
    logic [15:0] bus_write_data;
    logic [1:0] bus_beat_bytes;

    intel_80286_82c284_reset #(
        .RES_SYNC_DELAY_CLKS(RES_SYNC_DELAY_CLKS)
    ) reset_conditioner (
        .clk_i(clk_2x_i), .res_n_i(res_n_i), .reset_o(reset_from_res)
    );
    assign cpu_reset = reset_i | reset_from_res;
    assign cpu_reset_o = cpu_reset;

    /* verilator lint_off PINCONNECTEMPTY */
    intel_80286 #(.NATIVE_BEATS(1'b1)) core (
        .clk(clk_i), .rst_n(!cpu_reset),
        .bus_ready_i(core_ready), .bus_rdata_i(core_read_data),
        .intr_i(intr_i), .nmi_i(nmi_i),
        .busy_i(busy_i), .error_n_i(error_n_i),
        .inta_ready_i(inta_ready), .inta_vector_i(inta_vector),
        .inta_req_o(inta_request), .nmi_pending_o(), .nmi_blocked_o(),
        .bus_lock_o(core_lock),
        .bus_req_o(bus_request), .bus_halt_cycle_o(bus_halt_cycle),
        .bus_shutdown_cycle_o(bus_shutdown_cycle), .bus_addr_o(bus_address),
        .bus_fetch_o(bus_fetch), .bus_write_o(bus_write), .bus_io_o(bus_io),
        .bus_segmented_o(), .bus_segment_o(), .bus_kind_o(), .bus_offset_o(),
        .bus_size_o(), .bus_wdata_o(bus_write_data),
        .bus_beat_bytes_o(bus_beat_bytes),
        .halted_o(halted_o), .shutdown_o(shutdown_o),
        .fault_o(fault_o), .fault_code_o(fault_code_o),
        .retire_o(), .retire_pc_o(), .retire_opcode_o(), .regs_o(),
        .segs_o(), .seg_bases_o(), .seg_limits_o(), .seg_access_o(),
        .seg_valid_o(), .ip_o(), .flags_o(), .msw_o(), .cs_base_o(),
        .event_o(), .event_vector_o(), .event_packet_valid_o(),
        .event_packet_protected_o(), .event_packet_error_valid_o(),
        .event_packet_restartable_o(), .event_packet_error_code_o(),
        .event_packet_saved_cs_o(), .event_packet_saved_ip_o(),
        .event_packet_saved_flags_o(), .event_packet_saved_sp_o(),
        .event_packet_deferred_valid_o(), .event_packet_deferred_flags_valid_o(),
        .event_packet_deferred_register_write_o(),
        .event_packet_deferred_sp_valid_o(), .event_packet_deferred_register_o(),
        .event_packet_deferred_flags_o(), .event_packet_deferred_register_value_o(),
        .event_packet_deferred_sp_o(), .event_packet_deferred_ip_o(),
        .event_packet_deferred_call_o(), .element_o()
    );
    /* verilator lint_on PINCONNECTEMPTY */

    /* verilator lint_off PINCONNECTEMPTY */
    intel_80286_native_bus bus (
        .clk_i(clk_i), .reset_i(cpu_reset),
        .req_i(bus_request), .fetch_i(bus_fetch), .write_i(bus_write),
        .io_i(bus_io), .address_i(bus_address), .beat_bytes_i(bus_beat_bytes),
        .write_data_i(bus_write_data), .core_ready_o(core_ready),
        .completed_bytes_o(completed_bytes_o), .read_data_o(core_read_data),
        .ready_n_i(ready_n_i), .hold_i(hold_i),
        .lock_i(core_lock), .inta_req_i(inta_request),
        .inta_ready_o(inta_ready), .inta_vector_o(inta_vector),
        .halt_i(bus_halt_cycle), .shutdown_i(bus_shutdown_cycle),
        .data_i(data_i), .data_o(data_o), .data_oe_o(data_oe_o),
        .address_o(address_o), .address_oe_o(address_oe_o),
        .bhe_n_o(bhe_n_o), .cod_inta_o(cod_inta_o), .m_io_o(m_io_o),
        .s1_o(s1_o), .s0_o(s0_o), .status_oe_o(status_oe_o),
        .status_valid_o(),
        .lock_n_o(lock_n_o), .lock_oe_o(lock_oe_o), .hlda_o(hlda_o),
        .cycle_active_o(cycle_active_o), .protocol_error_o(protocol_error_o)
    );
    /* verilator lint_on PINCONNECTEMPTY */

    intel_80286_82288 bus_controller (
        .clk_i(clk_2x_i), .reset_i(cpu_reset),
        .status_valid_i(status_oe_o), .m_io_i(m_io_o), .s1_i(s1_o), .s0_i(s0_o),
        .cenl_i(cenl_i), .cen_i(cen_i), .cmdly_i(cmdly_i), .ready_n_i(ready_n_i),
        .ale_o(ale_o), .den_o(den_o), .dt_r_o(dt_r_o),
        .mrdc_n_o(mrdc_n_o), .mwtc_n_o(mwtc_n_o),
        .iorc_n_o(iorc_n_o), .iowc_n_o(iowc_n_o), .inta_n_o(inta_n_o),
        .mce_o(mce_o)
    );
endmodule
