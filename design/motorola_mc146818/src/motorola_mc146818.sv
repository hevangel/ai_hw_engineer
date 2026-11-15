// Motorola MC146818 real-time clock plus RAM.
//
// Source: MC146818 Advance Information ADI-856-R1 (Motorola 1983 "8-Bit
// Microprocessor and Peripheral Data", pp. 3-697..3-718). See
// spec/spec.md for the interface, register map and assumption ledger; the
// "ASSUMPTION Rn" tags below refer to it.
//
// Synchronous model: every input is sampled on clk. Bus strobe edges are
// detected on the sampled signals. tick_i is a clock enable for one
// oscillator (OSC1) period, or 2**FAST_SHIFT periods when FAST_SHIFT > 0.
// rst_n is the simulation/FPGA power-on reset; reset_n_i is the chip's
// RESET pin.
//
// Motorola bus mode of the MOTEL circuit only (DS low while AS is high).
module motorola_mc146818 #(
    parameter              NVRAM_FILE = "",  // $readmemh image of the 64 bytes (string)
    parameter int unsigned FAST_SHIFT = 0    // 0 = real time; one tick = 2**FAST_SHIFT periods
) (
    input  logic       clk,
    input  logic       rst_n,       // power-on reset of internal state (not the RESET pin)
    input  logic       tick_i,      // oscillator clock enable

    // Multiplexed bus
    input  logic       ce_n_i,      // CE, active low
    input  logic       as_i,        // AS, address strobe
    input  logic       ds_i,        // DS, data strobe
    input  logic       rw_i,        // R/W, 1 = read
    input  logic [7:0] ad_i,        // AD7-AD0 in
    output logic [7:0] ad_o,        // AD7-AD0 out
    output logic       ad_oe_o,     // AD7-AD0 driven

    input  logic       reset_n_i,   // RESET pin, active low
    input  logic       ps_i,        // PS (power sense) pin
    output logic       irq_n_o,     // IRQ: 0 = pulled low, 1 = released (open drain)
    output logic       sqw_o,       // SQW square-wave output

    // Side-effect-free debug read of the 64 locations (simulation dumps)
    input  logic [5:0] dbg_addr_i,
    output logic [7:0] dbg_data_o
);
    if (FAST_SHIFT > 10) begin : g_bad_fast_shift
        $error("FAST_SHIFT must be 0..10");
    end

    localparam logic [5:0] A_REGA = 6'h0A, A_REGB = 6'h0B, A_REGC = 6'h0C, A_REGD = 6'h0D;
    localparam logic [1:0] S_IDLE = 2'd0, S_BUC = 2'd1, S_UC = 2'd2;

    // ------------------------------------------------------------------
    // 64 locations. Register C keeps PF/AF/UF in bits 6:4 and register D
    // keeps VRT in bit 7; UIP and IRQF are derived. ASSUMPTION R14: the
    // power-on contents, including those bits, come from NVRAM_FILE (all
    // zero by default, so VRT = 0); rst_n does not change them.
    logic [7:0] mem   [64];
    logic [7:0] mem_n [64];

`ifndef FORMAL
    initial begin
        for (int i = 0; i < 64; i++) mem[i] = 8'h00;
        if (NVRAM_FILE != "") $readmemh(NVRAM_FILE, mem);
    end
`endif

    // Internal (non-battery-backed) state, cleared by rst_n.
    logic [5:0]  addr;
    logic        as_q, ds_q, rw_q, ce_n_q;
    logic [7:0]  ad_q;
    logic [7:0]  c_hold;           // register C double latch (p.3-711)
    logic [21:0] div;              // 22-stage divider in 4.194304 MHz periods
    logic [1:0]  seq;
    logic [10:0] cnt;              // oscillator periods left in tBUC / tUC
    logic        dst_done;         // October fall-back applied (R10)

    // ------------------------------------------------------------------
    // Register fields
    logic [6:0] rega;
    logic [7:0] regb;
    logic [2:0] flags;
    logic [2:0] dv;
    logic [3:0] rs;
    logic       pf, af, uf, vrt, uip, irqf;
    assign rega    = mem[A_REGA][6:0];
    assign regb    = mem[A_REGB];
    assign flags   = mem[A_REGC][6:4];
    assign dv      = rega[6:4];
    assign rs      = rega[3:0];
    assign pf      = flags[2];
    assign af      = flags[1];
    assign uf      = flags[0];
    assign vrt     = mem[A_REGD][7];
    assign uip     = (seq != S_IDLE);
    // IRQF = PF.PIE + AF.AIE + UF.UIE (p.3-714)
    assign irqf    = (pf & regb[6]) | (af & regb[5]) | (uf & regb[4]);
    assign irq_n_o = ~irqf;

    // ------------------------------------------------------------------
    // Divider (Table 4): DV 000 -> N=0, 001 -> N=2, 010 -> N=7, others held
    // in reset (ASSUMPTION R3 for the test codes 011, 100, 101).
    logic        run;
    logic [2:0]  nby;
    always_comb begin
        run = 1'b1;
        nby = 3'd0;
        case (dv)
            3'b000:  nby = 3'd0;
            3'b001:  nby = 3'd2;
            3'b010:  nby = 3'd7;
            default: run = 1'b0;
        endcase
    end

    logic [21:0] step, div_n;
    assign step  = 22'd1 << (5'(nby) + 5'(FAST_SHIFT));
    assign div_n = div + step;

    // Tap selection (Table 5): bit RS+5; RS=1/2 map to bits 13/14 with the
    // 32.768 kHz time base.
    logic       tap_en;
    logic [4:0] tap_k;
    always_comb begin
        tap_en = (rs != 4'd0);
        if (dv == 3'b010 && (rs == 4'd1 || rs == 4'd2)) tap_k = 5'(rs) + 5'd12;
        else                                            tap_k = 5'(rs) + 5'd5;
    end

    // Zero-extended copies so that a 5-bit tap index never selects out of range.
    logic [31:0] div_x, div_n_x;
    assign div_x   = {10'd0, div};
    assign div_n_x = {10'd0, div_n};

    logic tick_run, pf_edge, sec_edge;
    assign tick_run = tick_i & run;
    // ASSUMPTION R6: PF is set on the rising edge of the selected tap.
    assign pf_edge  = tick_run & tap_en & ~div_x[tap_k] & div_n_x[tap_k];
    assign sec_edge = tick_run & ~div[21] & div_n[21];
    assign sqw_o    = regb[3] & run & tap_en & div_x[tap_k];

    // Update-cycle timing (Table 6), ASSUMPTION R4.
    logic [10:0] t_buc, t_uc, stepc;
    always_comb begin
        case (nby)
            3'd0:    begin t_buc = 11'd1024; t_uc = 11'd1040; end
            3'd2:    begin t_buc = 11'd256;  t_uc = 11'd260;  end
            default: begin t_buc = 11'd8;    t_uc = 11'd65;   end
        endcase
        stepc = 11'd1 << FAST_SHIFT;
    end

    logic update_fire, uc_end;
    assign update_fire = tick_run & (seq == S_BUC) & (cnt <= stepc);
    assign uc_end      = tick_run & (seq == S_UC)  & (cnt <= stepc);

    // ------------------------------------------------------------------
    // Calendar arithmetic (Table 3, UPDATE CYCLE p.3-713)
    function automatic logic [7:0] inc8(input logic [7:0] v, input logic bin);
        // ASSUMPTION R7: BCD low digit >= 9 carries; high digit wraps mod 16.
        if (bin)               inc8 = v + 8'd1;
        else if (v[3:0] >= 4'd9) inc8 = {v[7:4] + 4'd1, 4'd0};
        else                   inc8 = v + 8'd1;
    endfunction

    function automatic logic [7:0] enc(input int unsigned x, input logic bin);
        enc = bin ? 8'(x) : {4'(x / 10), 4'(x % 10)};
    endfunction

    logic       bin, h24, dse;
    logic [7:0] t_sec, t_min, t_hr, t_dow, t_date, t_mon, t_yr;
    logic [7:0] n_sec, n_min, n_hr, n_dow, n_date, n_mon, n_yr;
    logic       n_dst_done, alarm_hit;
    logic [7:0] dim;
    logic       leap, at15959;

    assign bin    = regb[2];
    assign h24    = regb[1];
    assign dse    = regb[0];
    assign t_sec  = {1'b0, mem[0][6:0]};
    assign t_min  = mem[2];
    assign t_hr   = mem[4];
    assign t_dow  = mem[6];
    assign t_date = mem[7];
    assign t_mon  = mem[8];
    assign t_yr   = mem[9];

    always_comb begin
        // ASSUMPTION R8: leap year when the two-digit year is divisible by 4.
        if (bin) leap = (t_yr[1:0] == 2'd0);
        else     leap = (({t_yr[4], 1'b0} + t_yr[1:0]) == 2'd0);
        // ASSUMPTION R9: any other month value has 31 days.
        if (t_mon == 8'd2)
            dim = leap ? enc(29, bin) : enc(28, bin);
        else if (bin ? (t_mon == 8'd4 || t_mon == 8'd6 || t_mon == 8'd9 || t_mon == 8'd11)
                     : (t_mon == 8'h04 || t_mon == 8'h06 || t_mon == 8'h09 || t_mon == 8'h11))
            dim = enc(30, bin);
        else
            dim = enc(31, bin);
    end

    always_comb begin : upd
        logic c;
        logic pm;
        logic [7:0] h;
        n_sec = t_sec; n_min = t_min; n_hr = t_hr; n_dow = t_dow;
        n_date = t_date; n_mon = t_mon; n_yr = t_yr;
        n_dst_done = dst_done;
        c  = 1'b0;
        pm = 1'b0;
        h  = 8'h00;
        at15959 = (t_sec == enc(59, bin)) && (t_min == enc(59, bin)) && (t_hr == 8'h01);
        // ASSUMPTION R10: daylight saving (DSE, p.3-714) on the bytes before
        // the increment; last Sunday = day of week 1 and date >= 24 (April) or
        // >= 25 (October).
        if (dse && at15959 && t_dow == 8'h01 && t_mon == enc(4, bin) && t_date >= enc(24, bin)) begin
            n_sec = 8'h00; n_min = 8'h00; n_hr = 8'h03;
        end else if (dse && at15959 && t_dow == 8'h01 && t_mon == enc(10, bin)
                     && t_date >= enc(25, bin) && !dst_done) begin
            n_sec = 8'h00; n_min = 8'h00; n_hr = 8'h01;
            n_dst_done = 1'b1;
        end else begin
            // ASSUMPTION R7: a byte rolls over when >= its last legal value.
            if (t_sec >= enc(59, bin)) begin n_sec = 8'h00; c = 1'b1; end
            else n_sec = inc8(t_sec, bin);
            if (c) begin
                c = 1'b0;
                if (t_min >= enc(59, bin)) begin n_min = 8'h00; c = 1'b1; end
                else n_min = inc8(t_min, bin);
                if (c) begin
                    c = 1'b0;
                    if (h24) begin
                        if (t_hr >= enc(23, bin)) begin n_hr = 8'h00; c = 1'b1; end
                        else n_hr = inc8(t_hr, bin);
                    end else begin
                        pm = t_hr[7];
                        h  = {1'b0, t_hr[6:0]};
                        if (h >= enc(12, bin)) h = enc(1, bin);
                        else if (h == enc(11, bin)) begin
                            h  = enc(12, bin);
                            c  = pm;          // 11:59:59 PM -> 12:00:00 AM
                            pm = ~pm;
                        end else h = inc8(h, bin) & 8'h7F;
                        n_hr = {pm, h[6:0]};
                    end
                    if (c) begin
                        c = 1'b0;
                        n_dow = (t_dow >= 8'd7) ? 8'd1 : inc8(t_dow, bin);
                        if (t_date >= dim) begin n_date = 8'h01; c = 1'b1; end
                        else n_date = inc8(t_date, bin);
                        if (c) begin
                            c = 1'b0;
                            if (t_mon >= enc(12, bin)) begin n_mon = 8'h01; c = 1'b1; end
                            else n_mon = inc8(t_mon, bin);
                            if (c) begin
                                if (t_yr >= enc(99, bin)) n_yr = 8'h00;
                                else n_yr = inc8(t_yr, bin);
                            end
                        end
                    end
                end
            end
            if (n_hr != 8'h01) n_dst_done = 1'b0;
        end
        // Alarm (p.3-711): each byte equal, or don't care 11xxxxxx.
        alarm_hit = (mem[1] == n_sec || mem[1][7:6] == 2'b11)
                 && (mem[3] == n_min || mem[3][7:6] == 2'b11)
                 && (mem[5] == n_hr  || mem[5][7:6] == 2'b11);
    end

    // ------------------------------------------------------------------
    // Bus. Address latched at the AS falling edge, write at the DS falling
    // edge with R/W low, read side effects at the DS falling edge with R/W
    // high. ASSUMPTION R1: CE, R/W and AD are taken from the last clock the
    // strobe was high; nothing happens while RESET is low (p.3-709 g).
    logic as_fall, wr_end, rd_end, rd_c, rd_d;
    assign as_fall = as_q & ~as_i & ~ce_n_q & reset_n_i;
    assign wr_end  = ds_q & ~ds_i & ~rw_q & ~ce_n_q & reset_n_i;
    assign rd_end  = ds_q & ~ds_i &  rw_q & ~ce_n_q & reset_n_i;
    assign rd_c    = rd_end & (addr == A_REGC);
    assign rd_d    = rd_end & (addr == A_REGD);

    function automatic logic [7:0] view(input logic [5:0] a, input logic [7:0] creg);
        case (a)
            6'h00:   view = {1'b0, mem[0][6:0]};      // seconds bit 7 reads 0 (R13)
            A_REGA:  view = {uip, rega};
            A_REGC:  view = creg;                     // b3-b0 read 0
            A_REGD:  view = {vrt, 7'b0};              // b6-b0 read 0
            default: view = mem[a];
        endcase
    endfunction

    assign ad_oe_o    = ds_i & rw_i & ~ce_n_i & reset_n_i;
    assign ad_o       = view(addr, c_hold);
    assign dbg_data_o = view(dbg_addr_i, {irqf, pf, af, uf, 4'b0});

    // ------------------------------------------------------------------
    // Next-state of the 64 locations
    logic       set_rise, wr_time_ok, dv_reset_wr;
    logic [7:0] b_wr;
    always_comb begin
        for (int i = 0; i < 64; i++) mem_n[i] = mem[i];
        b_wr       = ad_q;
        set_rise   = wr_end && addr == A_REGB && ad_q[7] && !regb[7];
        if (set_rise) b_wr[4] = 1'b0;                 // SET going high clears UIE (p.3-714)
        // ASSUMPTION R5: time bytes are off the bus during the update cycle.
        wr_time_ok = (seq != S_UC) && !update_fire;
        dv_reset_wr = wr_end && addr == A_REGA && !(ad_q[6:4] == 3'b000 || ad_q[6:4] == 3'b001
                                                    || ad_q[6:4] == 3'b010);

        if (update_fire) begin
            mem_n[0] = n_sec;  mem_n[2] = n_min; mem_n[4] = n_hr;
            mem_n[6] = n_dow;  mem_n[7] = n_date; mem_n[8] = n_mon; mem_n[9] = n_yr;
        end
        if (wr_end) begin
            if (addr <= 6'd9) begin
                if (wr_time_ok) mem_n[addr] = (addr == 6'd0) ? {1'b0, ad_q[6:0]} : ad_q;
            end else if (addr == A_REGA) mem_n[A_REGA] = {1'b0, ad_q[6:0]};  // UIP read-only
            else if (addr == A_REGB)     mem_n[A_REGB] = b_wr;
            else if (addr == A_REGC || addr == A_REGD) begin
                // read-only (p.3-709)
            end else mem_n[addr] = ad_q;
        end

        // Register C flags: clear those read as 1, keep new events (p.3-711).
        mem_n[A_REGC] = {1'b0,
                         (pf & ~(rd_c & c_hold[6])) | pf_edge,
                         (af & ~(rd_c & c_hold[5])) | (update_fire & alarm_hit),
                         (uf & ~(rd_c & c_hold[4])) | uc_end,
                         4'b0};
        // RESET pin (p.3-708/709): PIE, AIE, UIE, SQWE and the flags cleared.
        if (!reset_n_i) begin
            mem_n[A_REGB][6:3] = 4'b0;
            mem_n[A_REGC]      = 8'h00;
        end
        // VRT: PS low clears it; a read of register D sets it (R12).
        if (!ps_i)      mem_n[A_REGD] = 8'h00;
        else if (rd_d)  mem_n[A_REGD] = 8'h80;
        else            mem_n[A_REGD] = {vrt, 7'b0};
    end

    always_ff @(posedge clk) mem <= mem_n;

    // ------------------------------------------------------------------
    // Internal state
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            addr     <= 6'd0;
            as_q     <= 1'b0;
            ds_q     <= 1'b0;
            rw_q     <= 1'b1;
            ce_n_q   <= 1'b1;
            ad_q     <= 8'h00;
            c_hold   <= 8'h00;
            div      <= 22'd0;
            seq      <= S_IDLE;
            cnt      <= 11'd0;
            dst_done <= 1'b0;
        end else begin
            as_q   <= as_i;
            ds_q   <= ds_i;
            rw_q   <= rw_i;
            ce_n_q <= ce_n_i;
            ad_q   <= ad_i;
            if (as_fall) addr <= ad_q[5:0];
            // Double latch: hold register C while DS is high.
            if (!ds_i) c_hold <= {irqf, pf, af, uf, 4'b0};

            if (tick_run) begin
                div <= div_n;
                case (seq)
                    S_BUC: if (cnt <= stepc) begin
                               seq <= S_UC;
                               cnt <= t_uc;
                               dst_done <= n_dst_done;
                           end else cnt <= cnt - stepc;
                    S_UC:  if (cnt <= stepc) begin
                               seq <= S_IDLE;
                               cnt <= 11'd0;
                           end else cnt <= cnt - stepc;
                    default:
                        // ASSUMPTION R2: UIP rises on the 1 Hz edge; the update
                        // follows tBUC later.
                        if (sec_edge && !regb[7]) begin
                            seq <= S_BUC;
                            cnt <= t_buc;
                        end
                endcase
            end
            // SET going high aborts the update and clears UIP (p.3-713/714);
            // a divider held in reset stops everything (Table 4).
            if (set_rise || !run || dv_reset_wr) begin
                seq <= S_IDLE;
                cnt <= 11'd0;
            end
            if (!run || dv_reset_wr) div <= 22'd0;
        end
    end

`ifdef FORMAL
    // ------------------------------------------------------------------
    // Properties (formal/motorola_mc146818.sby). The first cycle is reset.
    logic f_past;
    initial f_past = 1'b0;
    always_ff @(posedge clk) f_past <= 1'b1;
    always_comb if (!f_past) assume (!rst_n);

    (* anyconst *) logic [5:0] f_a;

    always_ff @(posedge clk) begin
        if (f_past && $past(rst_n) && rst_n) begin
            // IRQ pin and IRQF follow the flag/enable equation.
            assert (irq_n_o == !((pf && regb[6]) || (af && regb[5]) || (uf && regb[4])));
            assert (dbg_data_o[7] == irqf || dbg_addr_i != A_REGC);
            // Read-only bits never hold data that software could see.
            assert (mem[A_REGC][7] == 1'b0 && mem[A_REGC][3:0] == 4'b0);
            assert (mem[A_REGD][6:0] == 7'b0);
            // Register C clear-on-read: a flag read as 1 is cleared unless a
            // new event set it in the same clock.
            if ($past(rd_c && c_hold[6] && !pf_edge))                          assert (!pf);
            if ($past(rd_c && c_hold[5] && !(update_fire && alarm_hit)))       assert (!af);
            if ($past(rd_c && c_hold[4] && !uc_end))                           assert (!uf);
            // Flags only rise through their own events.
            if (!$past(pf) && pf) assert ($past(pf_edge));
            if (!$past(af) && af) assert ($past(update_fire && alarm_hit));
            if (!$past(uf) && uf) assert ($past(uc_end));
            // VRT only rises through a read of register D with PS high.
            if (!$past(vrt) && vrt) assert ($past(rd_d && ps_i));
            if (!$past(ps_i)) assert (!vrt);
            // UIP only rises on the 1 Hz edge with SET clear.
            if (!$past(uip) && uip) assert ($past(sec_edge && !regb[7]));
            if ($past(regb[7] && reset_n_i) && regb[7]) assert (!uip || $past(uip));
            // RESET pin: enables and flags cleared, IRQ released; time, RAM,
            // SET, DM, 24/12, DSE, DV and RS untouched; no bus write.
            if (!$past(reset_n_i)) begin
                assert (regb[6:3] == 4'b0 && !pf && !af && !uf && irq_n_o);
                assert (regb[7] == $past(regb[7]) && regb[2:0] == $past(regb[2:0]));
                assert (rega == $past(rega));
                if (f_a >= 6'h0E) assert (mem[f_a] == $past(mem[f_a]));
                if (f_a <= 6'h09 && !$past(update_fire)) assert (mem[f_a] == $past(mem[f_a]));
                assert (!$past(ad_oe_o));
            end
            // Writes to registers C and D change nothing.
            if ($past(wr_end && (addr == A_REGC || addr == A_REGD)) && $past(reset_n_i) && $past(ps_i)
                && !$past(rd_end))
                assert (vrt == $past(vrt));
            // A write never sets UIP or the seconds bit 7 that reads back.
            assert (dbg_addr_i != 6'h00 || dbg_data_o[7] == 1'b0);
            // Time bytes never change during the update cycle except by the update itself.
            if ($past(seq == S_UC) && f_a <= 6'h09 && f_a != 6'h00) assert (mem[f_a] == $past(mem[f_a]));
            // Sequencer uses only three states.
            assert (seq != 2'd3);
            assert (cnt <= 11'd1040);
        end
    end

    // Covers: each interrupt source fires (its flag set by its own event,
    // not by the power-on image) and drives IRQ; a read of register C clears
    // a flag; an update cycle runs from UIP through UF.
    always_ff @(posedge clk) begin
        if (f_past && rst_n && $past(rst_n)) begin
            cover ($past(pf_edge && !pf) && regb[6] && !irq_n_o);
            cover ($past(update_fire && alarm_hit && !af) && regb[5] && !irq_n_o);
            cover ($past(uc_end && !uf) && regb[4] && !irq_n_o);
            cover ($past(rd_c && uf) && !uf && irq_n_o);
            cover ($past(sec_edge && !uip) && uip);
            cover ($past(rd_d && !vrt) && vrt);
        end
    end
`endif
endmodule
