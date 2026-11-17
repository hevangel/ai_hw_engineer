// IBM PC AT I/O channel, 8-bit device cycles.
//
// The expansion slots carry SA0-SA19, SD0-SD7 and the -SMEMR, -SMEMW, -IOR
// and -IOW commands (Technical Reference, I/O channel description and logic
// sheets 19-20). A card that does not answer -MEM CS16 or -I/O CS16 is an
// 8-bit device: the system board runs a word access as two byte cycles and
// steers SD0-SD7 to the processor's high byte for an odd address.
//
// This module is that path for the two address ranges an adapter can own
// on this board model:
//   - memory A0000h-DFFFFh (below 1 MB, so -SMEMR/-SMEMW are generated);
//   - I/O at 100h and above that no system-board device decodes. The board
//     already splits a word I/O instruction into byte cycles, so each I/O
//     request here is one byte.
//
// ASSUMPTION AT18 (see spec): each byte cycle is one clock of address
// setup, CMD_CLKS clocks of command and one clock of hold. The real
// board's command timing for 8-bit devices (default wait states and the
// conversion state machine) is not modeled clock for clock; the card
// models attached here are transaction-accurate, not timing-accurate.
// I/O CH RDY is not used: no attached card stretches a cycle.
module at_io_channel #(
    parameter int unsigned CMD_CLKS = 4
) (
    input  logic        clk_i, reset_i,
    // Processor side (system board).
    input  logic        mem_cycle_i,       // memory cycle in its command phase
    input  logic        io_unclaimed_i,    // I/O byte cycle no board device decodes
    input  logic [23:0] address_i,
    input  logic [15:0] io_port_i,
    input  logic        bhe_n_i, write_i,
    input  logic [15:0] wdata_i,
    output logic        sel_o,             // this cycle belongs to the I/O channel
    output logic        ready_o,           // its data is valid / its write is done
    output logic [15:0] rdata_o,
    // Slot side.
    output logic [19:0] sa_o,
    output logic [7:0]  sd_o,
    input  logic [7:0]  sd_i,
    input  logic        sd_oe_i,           // a card drives SD0-SD7
    output logic        smemr_n_o, smemw_n_o, ior_n_o, iow_n_o
);
    typedef enum logic [2:0] {IDLE, SETUP, CMD, HOLD, DONE} state_t;
    state_t state;
    logic second;
    logic [7:0] count;
    logic mem_req, io_req, req, two_bytes;
    logic [7:0] wbyte;

    assign mem_req = mem_cycle_i && address_i[23:20] == 4'h0 &&
                     address_i[19:16] >= 4'hA && address_i[19:16] <= 4'hD;
    assign io_req = io_unclaimed_i && io_port_i >= 16'h0100;
    assign req = mem_req || io_req;
    assign two_bytes = mem_req && !bhe_n_i && !address_i[0];
    assign sa_o = mem_req ? {address_i[19:1], address_i[0] || second} : {4'h0, io_port_i};
    assign wbyte = sa_o[0] ? wdata_i[15:8] : wdata_i[7:0];
    assign sd_o = wbyte;
    assign sel_o = req;
    assign ready_o = req && state == DONE;

    assign smemr_n_o = !(state == CMD && mem_req && !write_i);
    assign smemw_n_o = !(state == CMD && mem_req && write_i);
    assign ior_n_o   = !(state == CMD && io_req && !write_i);
    assign iow_n_o   = !(state == CMD && io_req && write_i);

    always_ff @(posedge clk_i) begin
        if (reset_i || !req) begin
            state <= IDLE;
            second <= 1'b0;
            count <= '0;
        end else begin
            unique case (state)
                IDLE: begin
                    state <= SETUP;
                    second <= 1'b0;
                    // No pull-ups on the data bus: a lane nobody drives
                    // reads FFh (ASSUMPTION AT14).
                    rdata_o <= 16'hFFFF;
                end
                SETUP: begin
                    state <= CMD;
                    count <= '0;
                end
                CMD: begin
                    count <= count + 8'd1;
                    if (count == 8'(CMD_CLKS - 1)) begin
                        state <= HOLD;
                        if (!write_i && sd_oe_i) begin
                            if (sa_o[0]) rdata_o[15:8] <= sd_i;
                            else         rdata_o[7:0]  <= sd_i;
                        end
                    end
                end
                HOLD: begin
                    if (two_bytes && !second) begin
                        second <= 1'b1;
                        state <= SETUP;
                    end else state <= DONE;
                end
                DONE: ;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
