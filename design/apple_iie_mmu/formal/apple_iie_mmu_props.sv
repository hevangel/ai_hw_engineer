// Apple IIe MMU formal properties.
// Included inside apple_iie_mmu.sv under `ifdef FORMAL. Immediate asserts in
// clocked blocks only. The expected-value functions are restated from
// spec/spec.md (TRM Tables 4-6, 4-7, 7-9 and the reset description), not
// copied from the RTL expressions.

`ifdef FORMAL

logic f_past_valid;
initial f_past_valid = 1'b0;

// Spec restatement helpers (independent encoding: explicit range compare).
function automatic logic f_in_range(logic [15:0] v, logic [15:0] lo, logic [15:0] hi);
    f_in_range = (v >= lo) && (v <= hi);
endfunction

// Expected internal-ROM service in $Cxxx (spec "Internal ROM serves ..." rules;
// the $C300 rule precedes the $C100-$C7FF rule because $C300 lies inside it).
function automatic logic f_cxxx_int(logic [15:0] v,
                                    logic intcx_v, logic c8win_v, logic slotc3_v);
    f_cxxx_int = 1'b0;
    if (f_in_range(v, 16'hC000, 16'hC0FF))
        f_cxxx_int = 1'b0;                       // I/O page is never ROM
    else if (f_in_range(v, 16'hC300, 16'hC3FF))
        f_cxxx_int = !slotc3_v;
    else if (f_in_range(v, 16'hC100, 16'hC7FF))
        f_cxxx_int = intcx_v;
    else if (f_in_range(v, 16'hC800, 16'hCFFF))
        f_cxxx_int = intcx_v && c8win_v;
endfunction

// Expected array selection per spec priority (video pages, ALTZP ranges,
// RAMRD/RAMWRT), with the ROM-read / protected-write suppressions.
function automatic logic f_sel_aux(logic [15:0] v, logic rw_v,
                                   logic store80_v, logic hires_v, logic pg2_v,
                                   logic altzp_v, logic ramrd_v, logic ramwrt_v);
    f_sel_aux = 1'b0;
    if (f_in_range(v, 16'h0400, 16'h07FF) && store80_v)
        f_sel_aux = pg2_v;
    else if (f_in_range(v, 16'h2000, 16'h3FFF) && hires_v && store80_v)
        f_sel_aux = pg2_v;
    else if (f_in_range(v, 16'hD000, 16'hFFFF) || f_in_range(v, 16'h0000, 16'h01FF))
        f_sel_aux = altzp_v;
    else
        f_sel_aux = rw_v ? ramrd_v : ramwrt_v;
endfunction

// Expected RA column/row per TRM Table 7-9 (+ spec interleave on bit 12).
function automatic logic [7:0] f_row(logic [15:0] v);
    f_row = {v[8], v[7], v[5], v[4], v[3], v[2], v[1], v[0]};
endfunction

function automatic logic [7:0] f_col(logic [15:0] v, logic bank1_v);
    logic m12;
    m12 = (f_in_range(v, 16'hD000, 16'hDFFF) && bank1_v) ^ v[12];
    f_col = {v[15], v[14], v[13], m12, v[11], v[10], v[6], v[9]};
endfunction

(* anyconst *) logic [15:0] watched_addr;

logic exp_aux, exp_suppressed, exp_main, exp_int;
logic exp_rom1, exp_rom2;

always_comb begin
    exp_aux = f_sel_aux(watched_addr, rw, store80, hires, pg2,
                        altzp, ramrd, ramwrt);
    exp_suppressed = (rdrom && f_in_range(watched_addr, 16'hD000, 16'hFFFF) && rw)
                   || (!wren && f_in_range(watched_addr, 16'hD000, 16'hFFFF) && !rw)
                   || f_in_range(watched_addr, 16'hC000, 16'hCFFF);
    exp_int = f_cxxx_int(watched_addr, intcx, c8win, slotc3);
    exp_main = !exp_aux && !exp_suppressed && inh_n && !mpon;
    // Note: $D000-$FFFF RAM cycles are legal when write-enabled even while
    // ROM is read-selected (TRM ch.4), so no address-range restriction here;
    // the suppression terms already exclude the I/O page and ROM reads.
    exp_rom1 = inh_n && (exp_int
             || (rdrom && rw && f_in_range(watched_addr, 16'hD000, 16'hDFFF)));
    exp_rom2 = inh_n && rdrom && rw && f_in_range(watched_addr, 16'hE000, 16'hFFFF);
end

always_ff @(posedge clk) begin
    f_past_valid <= 1'b1;
    if (!f_past_valid) assume(!rst_n);

    if (rst_n) begin
        // 1. Array mutual exclusion; MPON/INH hold everything off.
        assert(!(main_cycle && aux_cycle));
        if (!inh_n || mpon) begin
            assert(ramen_n && en80_n);
        end

        // 2/3. Mapping agreement at the watched address.
        if (a == watched_addr) begin
            assert(ramen_n == !exp_main);
            assert(en80_n == !(!inh_off && !ram_suppressed && exp_aux));
            assert(romen1_n == !exp_rom1);
            assert(romen2_n == !exp_rom2);
            assert(cxxxout == (in_cxxx && !exp_int));
            if (f_in_range(a, 16'hC000, 16'hCFFF))
                assert(ramen_n && en80_n);
        end

        // 4. MD7/KBD' enable and value equations.
        assert(md7_oe == (rw && access_c01x && (a[3:0] >= 4'h1) && (a[3:0] <= 4'h8)));
        if (md7_oe) begin
            case (a[3:0])
                4'h1: assert(md7 == bank2);
                4'h2: assert(md7 == rdram);
                4'h3: assert(md7 == ramrd);
                4'h4: assert(md7 == ramwrt);
                4'h5: assert(md7 == intcx);
                4'h6: assert(md7 == altzp);
                4'h7: assert(md7 == slotc3);
                4'h8: assert(md7 == store80);
                default: assert(0);
            endcase
        end
        assert(kbd_n == !(rw && (access_c00x || access_c01x)));

        // 5. Prewrite transitions (LS175 next-state from the prior access).
        if (f_past_valid && $past(rst_n) && $past(access_c08x)) begin
            assert(bank2 == !$past(a[3]));
            assert(rdram == !($past(a[0]) ^ $past(a[1])));
            assert(fst_acc == ($past(a[0]) && $past(rw)));
            assert(wren == ($past(a[0]) ? (($past(rw) && $past(fst_acc)) || $past(wren))
                                        : 1'b0));
        end

        // 6. RA multiplexer and interleave at the watched address.
        if (a == watched_addr) begin
            assert(ra == (pras_n ? f_row(a) : f_col(a, !bank2)));
        end

        // 7. Window latch next state.
        if (f_past_valid && $past(rst_n)) begin
            if ($past(access_intc3)) begin
                assert(c8win);
            end else if ($past(a == 16'hCFFF)) begin
                assert(!c8win);
            end
        end

        // 8. MPON applies the reset state and holds the arrays off.
        if (mpon) assert(ramen_n && en80_n);
        if (f_past_valid && $past(rst_n) && $past(mpon)) begin
            assert(!store80 && !ramrd && !ramwrt);
            assert(!intcx && !altzp && !slotc3);
            assert(!pg2 && !hires);
            assert(bank2 && !rdram && wren && !fst_acc);
            assert(!c8win);
        end
    end

    // Reset state itself (checked on the first post-reset cycle).
    if (f_past_valid && $past(!rst_n) && rst_n) begin
        assert(!store80 && !ramrd && !ramwrt && !intcx && !altzp && !slotc3);
        assert(!pg2 && !hires && bank2 && !rdram && wren && !fst_acc && !c8win);
    end
end

`endif
