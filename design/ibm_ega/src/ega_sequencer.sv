// IBM EGA sequencer LSI (U33, TR p.18-23, sheet 2).
//
// Registers: Reset, Clocking Mode, Map Mask, Character Map Select, Memory
// Mode. Generates the dot clock enable and the character boundary from the
// selected master clock, the processor plane address (odd/even, chain,
// extended memory) and the per-plane write enables, and the character
// generator map for the display fetch.
module ega_sequencer (
    input  logic        clk,
    input  logic        rst_n,
    // processor I/O
    input  logic        addr_we,      // 3C4 write event
    input  logic        data_we,      // 3C5 write event
    input  logic [3:0]  wdata,         // data bits 7-4 are not used (TR p.18-23)
    // clocks
    input  logic        master_ce,
    output logic        dot_ce,       // one dot this clock
    output logic        char_ce,      // the dot is the first of a character
    output logic [3:0]  dot_idx,      // dot index within the character
    output logic [3:0]  char_w,       // 8 or 9, latched at the boundary
    // processor addressing
    input  logic [16:0] cpu_off,      // offset in the RAM window
    input  logic        map128,       // memory map 00 (128 KB)
    input  logic        chain,        // Graphics Miscellaneous bit 1
    input  logic        page,         // Misc Output bit 5
    output logic [15:0] cpu_paddr,
    output logic [3:0]  plane_we_mask,
    // display
    input  logic        attr_b3,      // attribute bit 3 of the fetched char
    output logic [1:0]  font_map,
    output logic        ext_mem,
    output logic        shift_load,
    output logic [39:0] dbg_regs,     // {memmode, cmap, mapmask, clock, reset}
    output logic [3:0]  idx
);
    logic [4:0] regs [0:4];
    logic [3:0] dotcnt;
    logic       half;
    logic       running;
    logic       is_dot;
    logic       oddeven;

    assign running = (regs[0][1:0] == 2'b11);
    assign dbg_regs = {3'b000, regs[4], 3'b000, regs[3], 3'b000, regs[2],
                       3'b000, regs[1], 3'b000, regs[0]};
    assign ext_mem = regs[4][1];
    assign shift_load = regs[1][2];
    assign oddeven = !regs[4][2];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            idx <= 4'd0;
            for (int i = 0; i < 5; i++) regs[i] <= 5'd0;
        end else begin
            if (addr_we) idx <= wdata[3:0];
            if (data_we) begin
                unique case (idx)
                    4'd0: regs[0] <= {3'b000, wdata[1:0]};
                    4'd1: regs[1] <= {1'b0, wdata[3:0]};
                    4'd2: regs[2] <= {1'b0, wdata[3:0]};
                    4'd3: regs[3] <= {1'b0, wdata[3:0]};
                    4'd4: regs[4] <= {2'b00, wdata[2:0]};
                    default: ;
                endcase
            end
            // TR p.23: the asynchronous reset clears Character Map Select
            if (!regs[0][0]) regs[3] <= 5'd0;
        end
    end

    // Dot clock: every master pulse, or every second one with Clocking
    // Mode bit 3 (ASSUMPTION E7: the first pulse is a dot). ASSUMPTION E6:
    // while halted there are no dots and the phase is cleared.
    always_comb begin
        if (!running || !master_ce) is_dot = 1'b0;
        else if (regs[1][3])        is_dot = !half;
        else                        is_dot = 1'b1;
    end
    assign dot_ce  = is_dot;
    assign char_ce = is_dot && (dotcnt == 4'd0);
    assign dot_idx = dotcnt;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            dotcnt <= 4'd0;
            half   <= 1'b0;
            char_w <= 4'd9;
        end else if (!running) begin
            dotcnt <= 4'd0;
            half   <= 1'b0;
        end else begin
            if (master_ce) half <= regs[1][3] ? !half : 1'b0;
            if (is_dot) begin
                if (dotcnt == 4'd0) begin
                    char_w <= regs[1][0] ? 4'd8 : 4'd9;
                    dotcnt <= 4'd1;
                end else begin
                    dotcnt <= (dotcnt + 4'd1 >= char_w) ? 4'd0 : dotcnt + 4'd1;
                end
            end
        end
    end

    // Processor plane address (TR p.23, p.52-53). ASSUMPTION E28: chained,
    // A0 is replaced by A16 (128 KB map) or by NOT the page bit.
    always_comb begin
        if (chain) cpu_paddr = {cpu_off[15:1], map128 ? cpu_off[16] : !page};
        else       cpu_paddr = cpu_off[15:0];
        if (!ext_mem) cpu_paddr[15:14] = 2'b00;
    end

    // Map Mask (TR p.21) restricted by odd/even (TR p.23).
    always_comb begin
        plane_we_mask = regs[2][3:0];
        if (oddeven) plane_we_mask = plane_we_mask & (cpu_off[0] ? 4'b1010 : 4'b0101);
    end

    // Character map (TR p.22-23). ASSUMPTION E17.
    always_comb begin
        if (ext_mem && regs[4][0] && (regs[3][3:2] != regs[3][1:0]) && attr_b3)
            font_map = regs[3][3:2];
        else if (ext_mem)
            font_map = regs[3][1:0];
        else
            font_map = 2'b00;
    end
endmodule
