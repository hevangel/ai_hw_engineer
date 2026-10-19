// Unexpanded KIM-1 decoder adapter for one original mask-programmed RRIOT.
module mos_6530_kim #(
    parameter bit SECOND = 0
) (
    input  logic        clk, rst_n, rw,
    input  logic [12:0] board_addr,
    input  logic [7:0]  data_i,
    output logic [7:0]  data_o,
    output logic        data_oe,
    input  logic [7:0]  pa_i, pb_i,
    output logic [7:0]  pa_o, pb_o, pa_oe, pb_oe,
    output logic        irq_n
);
    `include "mos_6530_kim_roms.svh"
    logic [7:0] pb_pins;
    logic rs;
    // This adapter owns PB6/K5; an external GPIO value on that pin is unused.
    logic unused_pb6;
    assign unused_pb6 = pb_i[6];
    assign rs = board_addr[12:10] != (SECOND ? 3'd6 : 3'd7);
    assign pb_pins = {pb_i[7], board_addr[12:10] != 3'd5, pb_i[5:0]};
    mos_6530 #(
        .ROM_CONTENTS(SECOND ? KIM003_ROM : KIM002_ROM),
        .RAM_MATCH(SECOND ? 13'h0780 : 13'h07c0),
        .IO_MATCH(SECOND ? 13'h0700 : 13'h0740)
    ) chip (
        .clk, .rst_n, .rw, .rs, .addr(board_addr[9:0]), .data_i, .data_o,
        .data_oe, .pa_i, .pb_i(pb_pins), .pa_o, .pb_o, .pa_oe, .pb_oe, .irq_n
    );
endmodule
