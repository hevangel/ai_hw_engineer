// Isolated original-software fixture; explicit environment in spec/spec.md.
module cia_software_top #(
    parameter bit TIMER_B_READ_LOSS = 1
) (
    input logic clk, rst_n, rdy_i, tod_input_i,
    input logic reference_cia_i, reference_irq_n_i, reference_nmi_n_i,
    input logic [7:0] memory_data_i,
    output logic [15:0] bus_addr, pc_o,
    output logic [7:0] bus_data_o, a_o, read_data_o,
    output logic [15:0] ta_count_o,
    output logic ta_underflow_o,
    output logic tb2_event_o, tb2_read_loss_o,
    output logic irq_n_o, nmi_n_o,
    output logic bus_we, fetch_o, fault_o, jammed_o
);
    logic cpu_clk, cia_selected, cia2_selected, unused_data_oe, irq_n, nmi_n;
    logic [7:0] cpu_data, cia_data, pa, pb, pa_o, pb_o, pa_oe, pb_oe;
    logic [7:0] cia2_data, pa2, pb2, pa2_o, pb2_o, pa2_oe, pb2_oe;
    logic unused_cnt, unused_cnt_oe, unused_sp, unused_sp_oe, unused_pc;
    logic unused_data2_oe, unused_cnt2, unused_cnt2_oe, unused_sp2, unused_sp2_oe, unused_pc2;
    logic [7:0] unused_status, unused_x, unused_y, unused_s;
    assign cpu_clk = !clk;
    assign cia_selected = bus_addr[15:8] == 8'hdc;
    assign cia2_selected = bus_addr[15:8] == 8'hdd;
    assign cpu_data = reference_cia_i ? memory_data_i : cia_selected ? cia_data : cia2_selected ? cia2_data : memory_data_i;
    assign read_data_o = cpu_data;
    assign ta_count_o = cia.unused_ta_count;
    assign ta_underflow_o = cia.ta_underflow;
    assign tb2_event_o = cia2.tb_event;
    assign tb2_read_loss_o = cia2.interrupt_control.read_i && cia2.interrupt_control.tb_loss_view;
    assign irq_n_o = reference_cia_i ? reference_irq_n_i : irq_n;
    assign nmi_n_o = reference_cia_i ? reference_nmi_n_i : nmi_n;
    assign pa = pa_o | ~pa_oe;
    assign pb = pb_o | ~pb_oe;
    assign pa2 = pa2_o | ~pa2_oe;
    assign pb2 = pb2_o | ~pb2_oe;
    mos_6502_native cpu (
        .clk(cpu_clk), .rst_n, .rdy_i, .irq_n(irq_n_o), .nmi_n(nmi_n_o), .so_n(1'b1),
        .bus_addr, .bus_data_i(cpu_data), .bus_data_o, .bus_we, .fetch_o, .fault_o, .jammed_o,
        .pc_o, .a_o, .status_o(unused_status), .x_o(unused_x), .y_o(unused_y), .s_o(unused_s)
    );
    mos_6526 #(.TIMER_B_READ_LOSS(TIMER_B_READ_LOSS)) cia (
        .clk, .rst_n, .cs_n(!cia_selected), .rw(!bus_we), .addr(bus_addr[3:0]),
        .data_i(bus_data_o), .data_o(cia_data), .data_oe(unused_data_oe),
        .pa_i(pa), .pb_i(pb), .pa_o, .pb_o, .pa_oe, .pb_oe,
        .cnt_i(1'b1), .sp_i(1'b1), .flag_n_i(1'b1), .tod_i(tod_input_i),
        .cnt_o(unused_cnt), .cnt_oe(unused_cnt_oe), .sp_o(unused_sp),
        .sp_oe(unused_sp_oe), .pc_n(unused_pc), .irq_n
    );
    mos_6526 #(.TIMER_B_READ_LOSS(TIMER_B_READ_LOSS)) cia2 (
        .clk, .rst_n, .cs_n(!cia2_selected), .rw(!bus_we), .addr(bus_addr[3:0]),
        .data_i(bus_data_o), .data_o(cia2_data), .data_oe(unused_data2_oe),
        .pa_i(pa2), .pb_i(pb2), .pa_o(pa2_o), .pb_o(pb2_o), .pa_oe(pa2_oe), .pb_oe(pb2_oe),
        .cnt_i(1'b1), .sp_i(1'b1), .flag_n_i(1'b1), .tod_i(tod_input_i),
        .cnt_o(unused_cnt2), .cnt_oe(unused_cnt2_oe), .sp_o(unused_sp2),
        .sp_oe(unused_sp2_oe), .pc_n(unused_pc2), .irq_n(nmi_n)
    );
endmodule
