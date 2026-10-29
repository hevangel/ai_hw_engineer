module mos_6530 #(
    parameter logic [8191:0] ROM_CONTENTS = {8192{1'b1}},
    parameter logic [12:0] ROM_MASK = 13'h0400,
    parameter logic [12:0] ROM_MATCH = 13'h0000,
    parameter logic [12:0] RAM_MASK = 13'h0fc0,
    parameter logic [12:0] RAM_MATCH = 13'h07c0,
    parameter logic [12:0] IO_MASK = 13'h0fc0,
    parameter logic [12:0] IO_MATCH = 13'h0740,
    parameter logic [7:0] SELECT_PINS = 8'h40
) (
    input  logic       clk, rst_n, rw, rs,
    input  logic [9:0] addr,
    input  logic [7:0] data_i,
    output logic [7:0] data_o,
    output logic       data_oe,
    input  logic [7:0] pa_i, pb_i,
    output logic [7:0] pa_o, pb_o, pa_oe, pb_oe,
    output logic       irq_n
);
    logic [7:0] ram [0:63];
    logic [7:0] ora, orb, ddra, ddrb, effective_ddrb;
    logic [7:0] timer_count;
    logic [9:0] divider, reload_divider;
    logic timer_running, timer_fast, timer_flag, timer_enable;
    logic [12:0] mask_inputs;
    logic rom_cs, ram_cs, io_cs, timer_write, timer_read;
    logic timer_tick, timer_expire, timer_irq;
    assign mask_inputs = {pb_i[5], pb_i[6], rs, addr};
    assign rom_cs = (mask_inputs & ROM_MASK) == ROM_MATCH;
    assign ram_cs = (mask_inputs & RAM_MASK) == RAM_MATCH;
    assign io_cs = (mask_inputs & IO_MASK) == IO_MATCH;
    assign data_oe = clk && rst_n && rw && (rom_cs || ram_cs || io_cs);
    assign timer_write = io_cs && !rw && addr[2];
    assign timer_read = io_cs && rw && addr[2] && !addr[0];
    assign timer_tick = timer_running && (timer_fast || divider == 0);
    assign timer_expire = timer_tick && !timer_fast && timer_count == 0;
    assign effective_ddrb = ddrb & ~SELECT_PINS;
    assign timer_irq = rst_n && !effective_ddrb[7] && timer_enable && timer_flag;
    assign pa_o = ora;
    assign pa_oe = ddra;
    assign pb_o = {effective_ddrb[7] ? orb[7] : !timer_irq, orb[6:0]};
    assign pb_oe = effective_ddrb | {timer_irq, 7'b0};
    assign irq_n = !rst_n || pb_o[7];

    always_comb begin
        data_o = 0;
        if (rom_cs) data_o = ROM_CONTENTS[{addr, 3'b0} +: 8];
        else if (ram_cs) data_o = ram[addr[5:0]];
        else if (io_cs) begin
            if (!addr[2]) begin
                case (addr[1:0])
                    0: data_o = (ora & ddra) | (pa_i & ~ddra);
                    1: data_o = ddra;
                    2: data_o = (orb & effective_ddrb) | (pb_i & ~effective_ddrb);
                    3: data_o = ddrb;
                    default: data_o = 0;
                endcase
            end else if (!addr[0]) data_o = timer_count;
            else data_o = {timer_flag, 7'b0};
        end
    end

    always_ff @(negedge clk) begin
        if (rst_n && ram_cs && !rw) ram[addr[5:0]] <= data_i;
        if (!rst_n) begin
            ora <= 0; orb <= 0; ddra <= 0; ddrb <= 0;
            // ASSUMPTION: deterministic stopped timer; internal reset contents unspecified.
            timer_count <= 0; divider <= 0; reload_divider <= 0;
            timer_running <= 0; timer_fast <= 0; timer_flag <= 0; timer_enable <= 0;
        end else begin
            if (io_cs && !rw && !addr[2]) begin
                case (addr[1:0])
                    0: ora <= data_i;
                    1: ddra <= data_i;
                    2: orb <= data_i;
                    // ASSUMPTION: reserved select-pin DDR bits retain write/readback.
                    3: ddrb <= data_i;
                    default: ;
                endcase
            end
            if (timer_write) begin
                timer_count <= data_i;
                divider <= 0;
                case (addr[1:0])
                    0: reload_divider <= 0;
                    1: reload_divider <= 7;
                    2: reload_divider <= 63;
                    3: reload_divider <= 1023;
                    default: reload_divider <= 0;
                endcase
                timer_running <= 1; timer_fast <= 0; timer_flag <= 0;
                timer_enable <= addr[3];
            end else begin
                if (timer_running) begin
                    if (timer_tick) begin
                        timer_count <= timer_count - 8'd1;
                        divider <= reload_divider;
                    end else divider <= divider - 10'd1;
                    if (timer_expire) begin
                        timer_flag <= 1;
                        timer_fast <= 1;
                    end
                end
                if (timer_read) begin
                    // KIM manual Appendix H: post-expiry read disables IRQ,
                    // even at the A3=1 alias. This differs from the 6532.
                    timer_enable <= timer_fast ? 1'b0 : addr[3];
                    if (!timer_expire) begin
                        timer_flag <= 0;
                        if (timer_fast) begin
                            // ASSUMPTION: returned count reloads original prescaler.
                            timer_count <= timer_count;
                            timer_fast <= 0;
                            divider <= 0;
                        end
                    end
                end
            end
        end
    end
`ifdef FORMAL
    `include "mos_6530_props.sv"
`endif
endmodule
