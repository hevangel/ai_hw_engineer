// Ricoh 5A22 (S-CPU): the SNES CPU package around a WDC 65C816 core.
// Adds the variable-speed bus cycle generator (6/8/12 master clocks), DRAM
// refresh, eight general-purpose/HDMA DMA channels, the NMI / H-V IRQ timer,
// the multiply and divide unit, joypad ports with auto-read, and the
// B-bus ($21xx) interface. Everything runs on the master clock; see
// spec/spec.md for the timing positions and the assumption ledger.
module ricoh_5a22 #(
    parameter bit PAL = 1'b0
) (
    input  logic clk,                 // master clock (21.477 MHz NTSC)
    input  logic rst_n,
    // A bus (24-bit). Strobes are held for the whole access; the access
    // completes on the clock where bus_ce is high.
    output logic [23:0] a_addr,
    output logic a_rd, a_wr,
    input  logic [7:0] a_data_i,
    input  logic a_hit,               // a device drove a_data_i
    // B bus ($21xx).
    output logic [7:0] b_addr,
    output logic b_rd, b_wr,
    input  logic [7:0] b_data_i,
    input  logic b_hit,
    output logic [7:0] data_o,        // write data (A or B bus)
    output logic bus_ce,              // last clock of the current access
    output logic refresh_o,           // DRAM refresh in progress
    output logic dma_o,               // DMA/HDMA owns the bus
    output logic [7:0] mdr_o,         // open-bus latch (last value on the data bus)
    // Interrupt and video timing.
    input  logic irq_n,               // cartridge /IRQ
    input  logic interlace_i,         // PPU $2133 bit 0
    input  logic overscan_i,          // PPU $2133 bit 2
    output logic [8:0] vcount_o,
    output logic [10:0] hcount_o,     // master clocks within the line
    output logic field_o,
    // I/O ports.
    output logic [7:0] wrio_o,
    input  logic [7:0] rdio_i,
    output logic jp_latch_o,
    output logic jp1_clk_o, jp2_clk_o, // one-clock pulses: shift the pads
    input  logic [1:0] jp1_d_i, jp2_d_i,
    // Debug.
    output logic cpu_fetch_o,
    output logic [23:0] cpu_pc_o,
    output logic [15:0] cpu_a_o, cpu_x_o, cpu_y_o, cpu_s_o, cpu_d_o,
    output logic [7:0] cpu_p_o, cpu_dbr_o,
    output logic cpu_e_o
);
    // ---------------- 65C816 core ----------------
    logic core_ce, core_we, core_vda, core_vpa;
    logic [23:0] core_addr;
    logic [7:0] core_do, core_di;
    logic nmi_line, irq_line;
    logic [15:0] core_pc;
    logic [7:0] core_pbr;
    /* verilator lint_off UNUSEDSIGNAL */
    logic core_vpb, core_ml, core_m, core_x, core_wait, core_stop;
    /* verilator lint_on UNUSEDSIGNAL */
    wdc_65c816 core (
        .clk, .ce(core_ce), .rst_n,
        .irq_n(!irq_line), .nmi_n(!nmi_line),
        .addr_o(core_addr), .data_i(core_di), .data_o(core_do), .we_o(core_we),
        .vda_o(core_vda), .vpa_o(core_vpa), .vpb_o(core_vpb), .ml_o(core_ml),
        .e_o(cpu_e_o), .m_o(core_m), .x_o(core_x), .fetch_o(cpu_fetch_o),
        .waiting_o(core_wait), .stopped_o(core_stop),
        .pc_o(core_pc), .a_o(cpu_a_o), .x_reg_o(cpu_x_o), .y_reg_o(cpu_y_o), .s_o(cpu_s_o),
        .d_o(cpu_d_o), .p_o(cpu_p_o), .dbr_o(cpu_dbr_o), .pbr_o(core_pbr)
    );
    assign cpu_pc_o = {core_pbr, core_pc};

    // ---------------- Video timing counters ----------------
    // 1364 master clocks per line (1360 on NTSC line 240 of the odd field
    // without interlace, 1368 on PAL line 311 of the odd interlaced field);
    // 262/263 (NTSC) or 312/313 (PAL) lines.
    logic [10:0] hcnt;
    logic [8:0] vcnt;
    logic field;
    wire [8:0] vblank_line = overscan_i ? 9'd240 : 9'd225;
    logic [10:0] line_len;
    logic [8:0] frame_lines;
    always_comb begin
        line_len = 11'd1364;
        if (!PAL && !interlace_i && field && vcnt == 9'd240) line_len = 11'd1360;
        if (PAL && interlace_i && field && vcnt == 9'd311) line_len = 11'd1368;
        frame_lines = PAL ? 9'd312 : 9'd262;
        if (interlace_i && !field) frame_lines = frame_lines + 9'd1;
    end
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            hcnt <= 11'd0;
            vcnt <= 9'd0;
            field <= 1'b0;
        end else if (hcnt == line_len - 11'd1) begin
            hcnt <= 11'd0;
            if (vcnt == frame_lines - 9'd1) begin
                vcnt <= 9'd0;
                field <= !field;
            end else vcnt <= vcnt + 9'd1;
        end else hcnt <= hcnt + 11'd1;
    end
    assign hcount_o = hcnt;
    assign vcount_o = vcnt;
    assign field_o = field;

    // ---------------- Registers ----------------
    /* verilator lint_off UNUSEDSIGNAL */
    logic [7:0] nmitimen;          // bits 6, 3-1 are unused on the 5A22
    /* verilator lint_on UNUSEDSIGNAL */
    logic [7:0] wrmpya, wrdivl, wrdivh, mdmaen, hdmaen;
    logic [8:0] htime, vtime;
    logic memsel;
    logic [15:0] rddiv, rdmpy;
    logic [3:0] mpyctr;
    logic [4:0] divctr;
    logic [22:0] shift;
    logic rdnmi, timeup;
    logic [15:0] joy [4];
    logic autojoy_busy;
    logic [12:0] autojoy_cnt;
    logic jp_latch_reg;
    logic [7:0] mdr;
    assign mdr_o = mdr;

    // DMA channel registers.
    logic [7:0] dmap [8], bbad [8], a1b [8], dasb [8], ntrl [8], unused [8];
    logic [15:0] a1t [8], das [8], a2a [8];
    logic [7:0] hdma_active;     // not terminated this frame
    logic [7:0] hdma_do;         // transfer on this line

    // ---------------- Bus sequencer ----------------
    typedef enum logic [2:0] { Q_CPU, Q_REFRESH, Q_DMA, Q_HDMA } seq_e;
    seq_e seq;
    logic [5:0] cnt;               // clocks into the current access
    logic refresh_pend, hdma_pend, hdma_init_pend, dma_pend;

    // CPU access classification.
    wire cpu_io = !core_vda && !core_vpa;
    wire cpu_low = !core_addr[22];                       // banks 00-3F / 80-BF
    wire cpu_b = cpu_low && core_addr[15:8] == 8'h21;
    wire cpu_int = cpu_low && (core_addr[15:0] == 16'h4016 || core_addr[15:0] == 16'h4017 ||
                   core_addr[15:8] == 8'h42 || core_addr[15:8] == 8'h43);
    logic [3:0] cpu_len;
    always_comb begin
        if (cpu_io) cpu_len = 4'd6;
        else if (core_addr[22] || core_addr[15]) cpu_len = (core_addr[23] && memsel) ? 4'd6 : 4'd8;
        else if (core_addr[14:13] == 2'b00 || core_addr[14:13] == 2'b11) cpu_len = 4'd8;
        else if (core_addr[14:9] == 6'b100000) cpu_len = 4'd12;   // $4000-$41FF
        else cpu_len = 4'd6;
    end

    // DMA engine state.
    typedef enum logic [3:0] {
        D_ALIGN, D_START, D_SETUP, D_XFER,
        H_START, H_XFER, H_NTRL, H_ADDR_L, H_ADDR_H, H_DONE, H_INIT
    } dstate_e;
    dstate_e dst;
    logic [2:0] dch, hch;          // GPDMA / HDMA channel
    logic [1:0] dbidx, hbidx;      // byte index in the transfer unit
    wire [2:0] ch = seq == Q_HDMA ? hch : dch;
    wire [1:0] bidx = seq == Q_HDMA ? hbidx : dbidx;
    logic init_pass;
    logic [7:0] wrio;
    logic [2:0] unit;              // clocks in the 8-clock DMA unit
    logic [2:0] mclk8;             // free-running divider for DMA alignment

    function automatic logic [1:0] b_offset(input logic [2:0] mode, input logic [1:0] i);
        case (mode)
            3'd1, 3'd5: b_offset = {1'b0, i[0]};
            3'd3, 3'd7: b_offset = {1'b0, i[1]};
            3'd4: b_offset = i;
            default: b_offset = 2'd0;
        endcase
    endfunction
    function automatic logic [1:0] unit_last(input logic [2:0] mode);
        case (mode)
            3'd0: unit_last = 2'd0;
            3'd1, 3'd2, 3'd6: unit_last = 2'd1;
            default: unit_last = 2'd3;
        endcase
    endfunction

    // Lowest set bit helpers for channel scheduling.
    function automatic logic [3:0] first_ch(input logic [7:0] m, input logic [2:0] from);
        first_ch = 4'd8;
        for (int i = 7; i >= 0; i--)
            if (m[i] && 3'(i) >= from) first_ch = 4'(i);
    endfunction

    logic [7:0] hdma_lines_mask;   // channels taking part in this HDMA pass
    logic indirect;
    assign indirect = dmap[ch][6];

    // Current access (combinational).
    logic dma_a_to_b;
    logic [23:0] dma_a;
    logic [7:0] dma_b;
    always_comb begin
        dma_a_to_b = !dmap[ch][7];
        dma_a = {a1b[ch], a1t[ch]};
        if (dst == H_XFER) dma_a = indirect ? {dasb[ch], das[ch]} : {a1b[ch], a2a[ch]};
        if (dst == H_NTRL || dst == H_ADDR_L || dst == H_ADDR_H || dst == H_INIT)
            dma_a = {a1b[ch], a2a[ch]};
        dma_b = bbad[ch] + {6'h00, b_offset(dmap[ch][2:0], bidx)};
    end

    wire dma_xfer = (seq == Q_DMA && dst == D_XFER) || (seq == Q_HDMA && dst == H_XFER);
    wire dma_tbl = seq == Q_HDMA && (dst == H_NTRL || dst == H_ADDR_L || dst == H_ADDR_H ||
                                     (dst == H_INIT && bidx != 2'd3));

    always_comb begin
        a_addr = core_addr;
        a_rd = 1'b0; a_wr = 1'b0;
        b_addr = core_addr[7:0];
        b_rd = 1'b0; b_wr = 1'b0;
        data_o = core_do;
        bus_ce = 1'b0;
        if (seq == Q_CPU) begin
            bus_ce = cnt == {2'b00, cpu_len - 4'd1};
            if (!cpu_io && !cpu_int) begin
                if (cpu_b) begin b_rd = !core_we; b_wr = core_we; end
                else begin a_rd = !core_we; a_wr = core_we; end
            end
        end else if (dma_xfer) begin
            bus_ce = unit == 3'd7;
            a_addr = dma_a;
            b_addr = dma_b;
            if (dma_a_to_b) begin a_rd = 1'b1; b_wr = 1'b1; data_o = a_hit ? a_data_i : mdr; end
            else begin b_rd = 1'b1; a_wr = 1'b1; data_o = b_hit ? b_data_i : mdr; end
        end else if (dma_tbl) begin
            bus_ce = unit == 3'd7;
            a_addr = dma_a;
            a_rd = 1'b1;
        end
    end
    assign refresh_o = seq == Q_REFRESH;
    assign dma_o = seq == Q_DMA || seq == Q_HDMA;

    // ---------------- Internal register reads ----------------
    logic [7:0] int_rdata;
    always_comb begin
        logic [3:0] c;
        c = core_addr[7:4];
        int_rdata = mdr;
        if (core_addr[15:8] == 8'h43) begin
            case (core_addr[3:0])
                4'h0: int_rdata = dmap[c[2:0]];
                4'h1: int_rdata = bbad[c[2:0]];
                4'h2: int_rdata = a1t[c[2:0]][7:0];
                4'h3: int_rdata = a1t[c[2:0]][15:8];
                4'h4: int_rdata = a1b[c[2:0]];
                4'h5: int_rdata = das[c[2:0]][7:0];
                4'h6: int_rdata = das[c[2:0]][15:8];
                4'h7: int_rdata = dasb[c[2:0]];
                4'h8: int_rdata = a2a[c[2:0]][7:0];
                4'h9: int_rdata = a2a[c[2:0]][15:8];
                4'ha: int_rdata = ntrl[c[2:0]];
                4'hb, 4'hf: int_rdata = unused[c[2:0]];
                default: int_rdata = mdr;
            endcase
            if (c[3]) int_rdata = mdr;
        end else begin
            case (core_addr[15:0])
                16'h4016: int_rdata = {mdr[7:2], jp1_d_i};
                16'h4017: int_rdata = {mdr[7:5], 3'b111, jp2_d_i};
                16'h4210: int_rdata = {rdnmi, mdr[6:4], 4'h2};
                16'h4211: int_rdata = {timeup, mdr[6:0]};
                16'h4212: int_rdata = {vcnt >= vblank_line, hcnt <= 11'd2 || hcnt >= 11'd1096,
                                       mdr[5:1], autojoy_busy};
                16'h4213: int_rdata = rdio_i;
                16'h4214: int_rdata = rddiv[7:0];
                16'h4215: int_rdata = rddiv[15:8];
                16'h4216: int_rdata = rdmpy[7:0];
                16'h4217: int_rdata = rdmpy[15:8];
                16'h4218: int_rdata = joy[0][7:0];
                16'h4219: int_rdata = joy[0][15:8];
                16'h421a: int_rdata = joy[1][7:0];
                16'h421b: int_rdata = joy[1][15:8];
                16'h421c: int_rdata = joy[2][7:0];
                16'h421d: int_rdata = joy[2][15:8];
                16'h421e: int_rdata = joy[3][7:0];
                16'h421f: int_rdata = joy[3][15:8];
                default: int_rdata = mdr;
            endcase
        end
    end
    always_comb begin
        if (cpu_int) core_di = int_rdata;
        else if (cpu_b) core_di = b_hit ? b_data_i : mdr;
        else core_di = a_hit ? a_data_i : mdr;
    end

    assign core_ce = seq == Q_CPU && bus_ce;
    assign nmi_line = rdnmi && nmitimen[7];
    assign irq_line = timeup || !irq_n;
    assign wrio_o = wrio;
    assign jp_latch_o = jp_latch_reg || (autojoy_busy && autojoy_cnt < 13'd12);

    // IRQ position: the H/V comparison sees counters 10 clocks late.
    wire [10:0] htime_clk = {htime, 2'b00} + 11'd14;
    wire virq_hit = vcnt == vtime;
    logic irq_cond;
    always_comb begin
        case (nmitimen[5:4])
            2'b01: irq_cond = hcnt == htime_clk;
            2'b10: irq_cond = virq_hit && hcnt == 11'd10;
            2'b11: irq_cond = virq_hit && hcnt == htime_clk;
            default: irq_cond = 1'b0;
        endcase
    end

    // Autojoy shift helper.
    wire autojoy_shift = autojoy_busy && autojoy_cnt >= 13'd128 && autojoy_cnt[7:0] == 8'd0 &&
                         autojoy_cnt < 13'd4224;

    // ---------------- Sequencer and registers ----------------
    always_ff @(posedge clk) begin
        jp1_clk_o <= 1'b0;
        jp2_clk_o <= 1'b0;
        if (!rst_n) begin
            seq <= Q_CPU;
            cnt <= 6'd0;
            mclk8 <= 3'd0;
            refresh_pend <= 1'b0;
            hdma_pend <= 1'b0;
            hdma_init_pend <= 1'b0;
            dma_pend <= 1'b0;
            nmitimen <= 8'h00;
            wrio <= 8'hff;
            mdmaen <= 8'h00;
            hdmaen <= 8'h00;
            memsel <= 1'b0;
            htime <= 9'h1ff;
            vtime <= 9'h1ff;
            rdnmi <= 1'b0;
            timeup <= 1'b0;
            mpyctr <= 4'd0;
            divctr <= 5'd0;
            autojoy_busy <= 1'b0;
            autojoy_cnt <= 13'd0;
            jp_latch_reg <= 1'b0;
            hdma_active <= 8'h00;
            hdma_do <= 8'h00;
            mdr <= 8'h00;
            for (int i = 0; i < 8; i++) begin
                dmap[i] <= 8'hff; bbad[i] <= 8'hff; a1b[i] <= 8'hff; dasb[i] <= 8'hff;
                ntrl[i] <= 8'hff; unused[i] <= 8'hff;
                a1t[i] <= 16'hffff; das[i] <= 16'hffff; a2a[i] <= 16'hffff;
            end
        end else begin
            mclk8 <= mclk8 + 3'd1;
            // ---- timing events ----
            if (hcnt == 11'd538) refresh_pend <= 1'b1;
            if (vcnt == 9'd0 && hcnt == 11'd12 && hdmaen != 8'h00) hdma_init_pend <= 1'b1;
            if (vcnt < vblank_line && hcnt == 11'd1104 && hdmaen != 8'h00) hdma_pend <= 1'b1;
            if (vcnt == 9'd0 && hcnt == 11'd12) hdma_active <= 8'h00;
            if (vcnt == vblank_line && hcnt == 11'd2) rdnmi <= 1'b1;
            if (vcnt == 9'd0 && hcnt == 11'd2) rdnmi <= 1'b0;
            if (irq_cond) timeup <= 1'b1;
            // ---- joypad auto-read ----
            if (vcnt == vblank_line && hcnt == 11'd130 && nmitimen[0]) begin
                autojoy_busy <= 1'b1;
                autojoy_cnt <= 13'd0;
                for (int i = 0; i < 4; i++) joy[i] <= 16'h0000;
            end else if (autojoy_busy) begin
                autojoy_cnt <= autojoy_cnt + 13'd1;
                if (autojoy_shift) begin
                    joy[0] <= {joy[0][14:0], jp1_d_i[0]};
                    joy[1] <= {joy[1][14:0], jp2_d_i[0]};
                    joy[2] <= {joy[2][14:0], jp1_d_i[1]};
                    joy[3] <= {joy[3][14:0], jp2_d_i[1]};
                    jp1_clk_o <= 1'b1;
                    jp2_clk_o <= 1'b1;
                end
                if (autojoy_cnt == 13'd4224) autojoy_busy <= 1'b0;
            end
            // ---- bus sequencer ----
            case (seq)
            Q_CPU: begin
                if (bus_ce) begin
                    cnt <= 6'd0;
                    // CPU access completed.
                    mdr <= core_we ? core_do : core_di;
                    alu_step();
                    if (cpu_int) begin
                        if (core_we) reg_write(core_addr[15:0], core_do);
                        else reg_read(core_addr[15:0]);
                    end
                    if (refresh_pend) begin
                        seq <= Q_REFRESH;
                        refresh_pend <= 1'b0;
                    end else if (hdma_init_pend || hdma_pend) begin
                        seq <= Q_HDMA;
                        start_hdma();
                    end else if (dma_pend || (cpu_int && core_we && core_addr[15:0] == 16'h420b &&
                                              core_do != 8'h00)) begin
                        seq <= Q_DMA;
                        dst <= D_ALIGN;
                        dma_pend <= 1'b0;
                    end
                end else cnt <= cnt + 6'd1;
            end
            Q_REFRESH: begin
                cnt <= cnt + 6'd1;
                if (cnt == 6'd39) begin
                    cnt <= 6'd0;
                    seq <= Q_CPU;
                end
            end
            Q_DMA: dma_clock();
            default: hdma_clock();
            endcase
        end
    end

    // Multiply / divide: one step per CPU bus cycle.
    task automatic alu_step;
        if (mpyctr != 4'd0) begin
            mpyctr <= mpyctr - 4'd1;
            if (rddiv[0]) rdmpy <= rdmpy + shift[15:0];
            rddiv <= rddiv >> 1;
            shift <= shift << 1;
        end
        if (divctr != 5'd0) begin
            logic [22:0] sh;
            divctr <= divctr - 5'd1;
            sh = shift >> 1;
            shift <= sh;
            if ({7'h00, rdmpy} >= sh) begin
                rdmpy <= rdmpy - sh[15:0];
                rddiv <= {rddiv[14:0], 1'b1};
            end else rddiv <= {rddiv[14:0], 1'b0};
        end
    endtask

    task automatic reg_read(input logic [15:0] ad);
        case (ad)
            16'h4016: jp1_clk_o <= 1'b1;
            16'h4017: jp2_clk_o <= 1'b1;
            16'h4210: rdnmi <= 1'b0;
            16'h4211: timeup <= 1'b0;
            default: ;
        endcase
    endtask

    task automatic reg_write(input logic [15:0] ad, input logic [7:0] dv);
        logic [2:0] c;
        c = ad[6:4];
        if (ad[15:8] == 8'h43) begin
            if (!ad[7])
                case (ad[3:0])
                    4'h0: dmap[c] <= dv;
                    4'h1: bbad[c] <= dv;
                    4'h2: a1t[c][7:0] <= dv;
                    4'h3: a1t[c][15:8] <= dv;
                    4'h4: a1b[c] <= dv;
                    4'h5: das[c][7:0] <= dv;
                    4'h6: das[c][15:8] <= dv;
                    4'h7: dasb[c] <= dv;
                    4'h8: a2a[c][7:0] <= dv;
                    4'h9: a2a[c][15:8] <= dv;
                    4'ha: ntrl[c] <= dv;
                    4'hb, 4'hf: unused[c] <= dv;
                    default: ;
                endcase
        end else
            case (ad)
                16'h4016: jp_latch_reg <= dv[0];
                16'h4200: begin
                    nmitimen <= dv;
                    if (dv[5:4] == 2'b00) timeup <= 1'b0;
                end
                16'h4201: wrio <= dv;
                16'h4202: wrmpya <= dv;
                16'h4203: begin
                    rdmpy <= 16'h0000;
                    if (mpyctr == 4'd0 && divctr == 5'd0) begin
                        rddiv <= {dv, wrmpya};
                        mpyctr <= 4'd8;
                        shift <= {15'h0000, dv};
                    end
                end
                16'h4204: wrdivl <= dv;
                16'h4205: wrdivh <= dv;
                16'h4206: begin
                    rdmpy <= {wrdivh, wrdivl};
                    if (mpyctr == 4'd0 && divctr == 5'd0) begin
                        divctr <= 5'd16;
                        shift <= {dv, 15'h0000} << 1;
                    end
                end
                16'h4207: htime[7:0] <= dv;
                16'h4208: htime[8] <= dv[0];
                16'h4209: vtime[7:0] <= dv;
                16'h420a: vtime[8] <= dv[0];
                16'h420b: mdmaen <= dv;
                16'h420c: hdmaen <= dv;
                16'h420d: memsel <= dv[0];
                default: ;
            endcase
    endtask

    // ---------------- General-purpose DMA ----------------
    task automatic dma_clock;
        logic [3:0] nxt;
        unit <= unit + 3'd1;
        case (dst)
            D_ALIGN: if (mclk8 == 3'd7) begin dst <= D_START; unit <= 3'd0; end
            D_START: if (unit == 3'd7) begin
                nxt = first_ch(mdmaen, 3'd0);
                if (nxt[3]) finish_dma();
                else begin dch <= nxt[2:0]; dst <= D_SETUP; end
            end
            D_SETUP: if (unit == 3'd7) begin dst <= D_XFER; dbidx <= 2'd0; end
            D_XFER: if (unit == 3'd7) begin
                mdr <= data_o;
                case (dmap[ch][4:3])
                    2'b00: a1t[ch] <= a1t[ch] + 16'd1;
                    2'b10: a1t[ch] <= a1t[ch] - 16'd1;
                    default: ;
                endcase
                dbidx <= dbidx + 2'd1;
                das[ch] <= das[ch] - 16'd1;
                if (das[ch] == 16'd1) begin
                    mdmaen[ch] <= 1'b0;
                    nxt = first_ch(mdmaen & ~(8'd1 << ch), ch);
                    if (nxt[3]) finish_dma();
                    else begin dch <= nxt[2:0]; dst <= D_SETUP; end
                end else if (hdma_pend || hdma_init_pend) begin
                    // HDMA pre-empts between bytes; the transfer resumes after.
                    seq <= Q_HDMA;
                    dma_pend <= 1'b1;
                    start_hdma();
                end
            end
            default: finish_dma();
        endcase
    endtask

    task automatic finish_dma;
        seq <= Q_CPU;
        cnt <= 6'd0;
    endtask

    // ---------------- HDMA ----------------
    task automatic start_hdma;
        unit <= 3'd0;
        hbidx <= 2'd0;
        if (hdma_init_pend) begin
            hdma_init_pend <= 1'b0;
            hdma_lines_mask <= hdmaen;
            hdma_active <= hdmaen;
            dst <= H_START;
            hch <= 3'd0;
            // Initialisation pass: H_INIT reloads each channel.
            hdma_do <= 8'hff;
            init_pass <= 1'b1;
        end else begin
            hdma_pend <= 1'b0;
            hdma_lines_mask <= hdmaen & hdma_active;
            dst <= H_START;
            hch <= 3'd0;
            init_pass <= 1'b0;
        end
    endtask

    task automatic hdma_clock;
        logic [3:0] nxt;
        logic [7:0] dv;
        logic [7:0] cnt7;
        unit <= unit + 3'd1;
        dv = a_hit ? a_data_i : mdr;
        case (dst)
            H_START: if (unit == 3'd7) begin
                nxt = first_ch(hdma_lines_mask, 3'd0);
                if (nxt[3]) hdma_end();
                else begin
                    hch <= nxt[2:0];
                    hbidx <= 2'd0;
                    if (init_pass) begin
                        a2a[nxt[2:0]] <= a1t[nxt[2:0]];
                        dst <= H_NTRL;
                    end else dst <= hdma_do[nxt[2:0]] ? H_XFER : H_DONE;
                end
            end
            H_XFER: if (unit == 3'd7) begin
                mdr <= data_o;
                if (indirect) das[ch] <= das[ch] + 16'd1;
                else a2a[ch] <= a2a[ch] + 16'd1;
                hbidx <= hbidx + 2'd1;
                if (hbidx == unit_last(dmap[ch][2:0])) dst <= H_DONE;
            end
            H_DONE: begin
                // Line counter update (no bus time of its own).
                cnt7 = ntrl[ch] - 8'd1;
                ntrl[ch] <= cnt7;
                hdma_do[ch] <= cnt7[7];
                unit <= 3'd0;
                if (cnt7[6:0] == 7'd0) dst <= H_NTRL;
                else hdma_next();
            end
            H_NTRL: if (unit == 3'd7) begin
                ntrl[ch] <= dv;
                a2a[ch] <= a2a[ch] + 16'd1;
                hdma_do[ch] <= 1'b1;
                mdr <= dv;
                if (indirect) dst <= H_ADDR_L;
                else begin
                    if (dv == 8'h00) hdma_active[ch] <= 1'b0;
                    hdma_next();
                end
            end
            H_ADDR_L: if (unit == 3'd7) begin
                das[ch][7:0] <= dv;
                a2a[ch] <= a2a[ch] + 16'd1;
                mdr <= dv;
                dst <= H_ADDR_H;
            end
            H_ADDR_H: if (unit == 3'd7) begin
                das[ch][15:8] <= dv;
                a2a[ch] <= a2a[ch] + 16'd1;
                mdr <= dv;
                if (ntrl[ch] == 8'h00) hdma_active[ch] <= 1'b0;
                hdma_next();
            end
            default: hdma_end();
        endcase
    endtask

    task automatic hdma_next;
        logic [3:0] nxt;
        nxt = first_ch(hdma_lines_mask & ~((8'd2 << ch) - 8'd1), 3'd0);
        unit <= 3'd0;
        hbidx <= 2'd0;
        if (nxt[3]) hdma_end();
        else begin
            hch <= nxt[2:0];
            if (init_pass) begin
                a2a[nxt[2:0]] <= a1t[nxt[2:0]];
                dst <= H_NTRL;
            end else dst <= hdma_do[nxt[2:0]] ? H_XFER : H_DONE;
        end
    endtask

    task automatic hdma_end;
        if (dma_pend) begin
            seq <= Q_DMA;
            dst <= D_XFER;
            dma_pend <= 1'b0;
        end else begin
            seq <= Q_CPU;
            cnt <= 6'd0;
        end
        unit <= 3'd0;
    endtask
endmodule
