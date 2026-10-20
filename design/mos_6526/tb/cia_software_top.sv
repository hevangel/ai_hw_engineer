// Isolated original-software fixture; explicit environment in spec/spec.md.
module cia_software_top (
    input logic clk, rst_n,
    input logic [7:0] memory_data_i,
    output logic [15:0] bus_addr, pc_o,
    output logic [7:0] bus_data_o, a_o, read_data_o,
    output logic [15:0] ta_count_o,
    output logic ta_underflow_o,
    output logic bus_we, fetch_o, fault_o, jammed_o
);
    logic cpu_clk, cia_selected, unused_data_oe, irq_n;
    logic [7:0] cpu_data, cia_data, pa, pb, pa_o, pb_o, pa_oe, pb_oe;
    logic unused_cnt, unused_cnt_oe, unused_sp, unused_sp_oe, unused_pc;
    logic [7:0] unused_status, unused_x, unused_y, unused_s;
    assign cpu_clk = !clk;
    assign cia_selected = bus_addr[15:8] == 8'hdc;
    assign cpu_data = cia_selected ? cia_data : memory_data_i;
    assign read_data_o = cpu_data;
    assign ta_count_o = cia.ta_count;
    assign ta_underflow_o = cia.ta_underflow;
    assign pa = pa_o | ~pa_oe;
    assign pb = pb_o | ~pb_oe;
    mos_6502_native cpu (
        .clk(cpu_clk), .rst_n, .rdy_i(1'b1), .irq_n, .nmi_n(1'b1), .so_n(1'b1),
        .bus_addr, .bus_data_i(cpu_data), .bus_data_o, .bus_we, .fetch_o, .fault_o, .jammed_o,
        .pc_o, .a_o, .status_o(unused_status), .x_o(unused_x), .y_o(unused_y), .s_o(unused_s)
    );
    mos_6526 cia (
        .clk, .rst_n, .cs_n(!cia_selected), .rw(!bus_we), .addr(bus_addr[3:0]),
        .data_i(bus_data_o), .data_o(cia_data), .data_oe(unused_data_oe),
        .pa_i(pa), .pb_i(pb), .pa_o, .pb_o, .pa_oe, .pb_oe,
        .cnt_i(1'b1), .sp_i(1'b1), .flag_n_i(1'b1), .tod_i(1'b0),
        .cnt_o(unused_cnt), .cnt_oe(unused_cnt_oe), .sp_o(unused_sp),
        .sp_oe(unused_sp_oe), .pc_n(unused_pc), .irq_n
    );
endmodule
