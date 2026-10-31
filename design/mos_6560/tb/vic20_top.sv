// Original-firmware VIC-20 fixture: native 6502, two 6522 VIAs and the VIC.
// Memory/ROM/color RAM live in the C++ harness. Board decode follows MAME's
// vic20 map (pinned in report/vic20_software.md); keyboard, joystick, IEC,
// cassette and user port are idle (all lines high).
module vic20_top #(
    parameter bit PAL = 1'b1
) (
    input  logic        clk, rst_n,
    input  logic [7:0]  memory_data_i,
    input  logic [11:0] vic_fetch_data_i,
    output logic [15:0] bus_addr, pc_o,
    output logic [7:0]  bus_data_o, read_data_o, a_o,
    output logic        bus_we, fetch_o, fault_o, jammed_o,
    output logic        vic_fetch_o, vic_matrix_o,
    output logic [13:0] vic_fetch_addr_o,
    output logic [15:0] pixel_o,
    output logic [6:0]  scan_h_o,
    output logic [8:0]  scan_line_o,
    output logic        frame_end_o, lightpen_n_o, irq_n_o, nmi_n_o,
    output logic        audio_sample_o,
    output logic [8:0]  audio_level_o
);
    logic cpu_clk, io, vic_sel, via1_sel, via2_sel;
    logic [7:0] vic_data, via1_data, via2_data;
    logic vic_oe, via1_oe, via2_oe;
    logic [7:0] pa1, pb1, pa1_o, pb1_o, pa1_oe, pb1_oe;
    logic [7:0] pa2, pb2, pa2_o, pb2_o, pa2_oe, pb2_oe;
    logic [7:0] unused_status, unused_x, unused_y, unused_s;
    logic [3:0] unused_voices;
    logic unused_ca2_1, unused_ca2_oe_1, unused_cb1_1, unused_cb1_oe_1;
    logic unused_cb2_1, unused_cb2_oe_1, unused_ca2_2, unused_ca2_oe_2;
    logic unused_cb1_2, unused_cb1_oe_2, unused_cb2_2, unused_cb2_oe_2;
    assign cpu_clk = !clk;
    // $9000-$900F VIC; VIA1 on A4 and VIA2 on A5 elsewhere in $9000-$93FF.
    assign io = bus_addr[15:10] == 6'b100100;
    assign vic_sel = bus_addr[15:4] == 12'h900;
    assign via1_sel = io && !vic_sel && bus_addr[4];
    assign via2_sel = io && !vic_sel && bus_addr[5];
    assign pa1 = pa1_o | ~pa1_oe;
    assign pb1 = pb1_o | ~pb1_oe;
    assign pa2 = pa2_o | ~pa2_oe;
    assign pb2 = pb2_o | ~pb2_oe;
    // VIA1 PA5 drives the VIC light-pen input (fire button idle high).
    assign lightpen_n_o = pa1[5];
    always_comb begin
        read_data_o = memory_data_i;
        if (vic_sel && vic_oe) read_data_o = vic_data;
        else if (via1_sel && via2_sel) read_data_o = via1_data & via2_data;
        else if (via1_sel) read_data_o = via1_data;
        else if (via2_sel) read_data_o = via2_data;
    end
    logic unused_oe;
    assign unused_oe = via1_oe ^ via2_oe;

    mos_6502_native cpu (
        .clk(cpu_clk), .rst_n, .rdy_i(1'b1), .irq_n(irq_n_o), .nmi_n(nmi_n_o), .so_n(1'b1),
        .bus_addr, .bus_data_i(read_data_o), .bus_data_o, .bus_we, .fetch_o, .fault_o,
        .jammed_o, .pc_o, .a_o, .status_o(unused_status), .x_o(unused_x), .y_o(unused_y),
        .s_o(unused_s)
    );

    mos_6560 #(.PAL(PAL)) vic (
        .clk, .rst_n, .ce_i(1'b1), .phi2_i(1'b1), .rw_i(!bus_we),
        .addr_i(vic_sel ? {10'b0100000000, bus_addr[3:0]} : 14'h0000),
        .data_i(bus_data_o), .data_o(vic_data), .data_oe_o(vic_oe),
        .fetch_o(vic_fetch_o), .fetch_matrix_o(vic_matrix_o),
        .fetch_addr_o(vic_fetch_addr_o), .fetch_data_i(vic_fetch_data_i),
        .pixel_o, .scan_h_o, .scan_line_o, .frame_end_o,
        .lightpen_n_i(lightpen_n_o), .pot_x_i(8'hff), .pot_y_i(8'hff),
        .audio_sample_o, .audio_voices_o(unused_voices), .audio_level_o
    );

    // VIA1: NMI (RESTORE on CA1); VIA2: IRQ (keyboard scan, jiffy timer).
    mos_6522 via1 (
        .clk, .rst_n, .cs1(via1_sel), .cs2_n(1'b0), .rw(!bus_we), .addr(bus_addr[3:0]),
        .data_i(bus_data_o), .data_o(via1_data), .data_oe(via1_oe),
        .pa_i(pa1), .pb_i(pb1), .pa_o(pa1_o), .pb_o(pb1_o), .pa_oe(pa1_oe), .pb_oe(pb1_oe),
        .ca1_i(1'b1), .ca2_i(1'b1), .cb1_i(1'b1), .cb2_i(1'b1),
        .ca2_o(unused_ca2_1), .ca2_oe(unused_ca2_oe_1), .cb1_o(unused_cb1_1),
        .cb1_oe(unused_cb1_oe_1), .cb2_o(unused_cb2_1), .cb2_oe(unused_cb2_oe_1),
        .irq_n(nmi_n_o)
    );
    mos_6522 via2 (
        .clk, .rst_n, .cs1(via2_sel), .cs2_n(1'b0), .rw(!bus_we), .addr(bus_addr[3:0]),
        .data_i(bus_data_o), .data_o(via2_data), .data_oe(via2_oe),
        .pa_i(pa2), .pb_i(pb2), .pa_o(pa2_o), .pb_o(pb2_o), .pa_oe(pa2_oe), .pb_oe(pb2_oe),
        .ca1_i(1'b1), .ca2_i(1'b1), .cb1_i(1'b1), .cb2_i(1'b1),
        .ca2_o(unused_ca2_2), .ca2_oe(unused_ca2_oe_2), .cb1_o(unused_cb1_2),
        .cb1_oe(unused_cb1_oe_2), .cb2_o(unused_cb2_2), .cb2_oe(unused_cb2_oe_2),
        .irq_n(irq_n_o)
    );
endmodule
