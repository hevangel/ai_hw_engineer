// Apple IIe MMU self-checking testbench.
//
// The reference model below is an independent encoding of spec/spec.md
// (TRM Tables 4-6, 4-7, 7-9, the internal-ROM/window rules and the reset
// description). Every access is compared against the model before the
// committing clock edge; the model state then updates with the same access.

`timescale 1ns/1ps

module tb_top;

    localparam int TCK = 100;   // clock period in ns; one access per cycle

    logic clk = 1'b0;
    always #(TCK/2) clk = ~clk;

    logic        rst_n;
    logic [15:0] a;
    logic        rw;
    logic        pras_n;
    logic        inh_n = 1'b1;
    logic        dma_n = 1'b1;

    wire [7:0]   ra;
    wire         ramen_n, en80_n, romen1_n, romen2_n;
    wire         cxxxout, kbd_n, md7, md7_oe, rw245;

    apple_iie_mmu dut (
        .clk, .rst_n, .a, .rw, .pras_n, .inh_n, .dma_n,
        .ra, .ramen_n, .en80_n, .romen1_n, .romen2_n,
        .cxxxout, .kbd_n, .md7, .md7_oe, .rw245
    );

    // ------------------------------------------------------------------
    // Check accounting
    // ------------------------------------------------------------------
    int checks = 0;
    int errors = 0;
    bit cap_md7;                // MD7 captured during the last access
    bit [7:0] cap_ra;           // RA captured in the driven phase

    task automatic check(input bit ok, input string what);
        checks++;
        if (!ok) begin
            errors++;
            $display("CHECK FAILED [%s] at %0t: a=%h rw=%b ramen=%b en80=%b rom1=%b rom2=%b cxxx=%b kbd=%b md7=%b/%b rw245=%b ra=%h",
                     what, $time, a, rw, ramen_n, en80_n, romen1_n, romen2_n,
                     cxxxout, kbd_n, md7, md7_oe, rw245, ra);
        end
    endtask

    // ------------------------------------------------------------------
    // Reference model state (spec/spec.md encoding)
    // ------------------------------------------------------------------
    bit r_store80, r_ramrd, r_ramwrt, r_intcx, r_altzp, r_slotc3;
    bit r_pg2, r_hires;
    bit r_bank2, r_rdram, r_wren, r_fst, r_c8win;
    bit r_s1, r_s2, r_s3;

    function automatic bit f_rng(bit [15:0] v, bit [15:0] lo, bit [15:0] hi);
        f_rng = (v >= lo) && (v <= hi);
    endfunction

    task automatic ref_reset_state;
        r_store80 = 0; r_ramrd = 0; r_ramwrt = 0;
        r_intcx = 0; r_altzp = 0; r_slotc3 = 0;
        r_pg2 = 0; r_hires = 0;
        r_bank2 = 1; r_rdram = 0; r_wren = 1; r_fst = 0; r_c8win = 0;
        r_s1 = 0; r_s2 = 0; r_s3 = 0;
    endtask

    // Expected outputs for one presented access, checked against the DUT.
    task automatic ref_compute(input bit [15:0] addr, input bit rw_i,
                               input bit inh_i, input bit dma_i, input bit pras_i);
        bit mpon, sel_aux, suppressed, main_c, aux_c, int_rom;
        bit exp_ramen_n, exp_en80_n, exp_rom1_n, exp_rom2_n;
        bit exp_cxxx, exp_kbd_n, exp_md7, exp_md7_oe, exp_rw245;
        bit m12;
        bit [7:0] exp_ra;

        mpon = (addr == 16'hFFFC) && r_s1 && r_s2 && r_s3;

        if ((f_rng(addr, 16'h0400, 16'h07FF) && r_store80) ||
            (f_rng(addr, 16'h2000, 16'h3FFF) && r_hires && r_store80))
            sel_aux = r_pg2;
        else if (f_rng(addr, 16'hD000, 16'hFFFF) || f_rng(addr, 16'h0000, 16'h01FF))
            sel_aux = r_altzp;
        else
            sel_aux = rw_i ? r_ramrd : r_ramwrt;

        suppressed = (r_rdram == 0 && f_rng(addr, 16'hD000, 16'hFFFF) && rw_i)
                   || (r_wren == 0 && f_rng(addr, 16'hD000, 16'hFFFF) && !rw_i)
                   || f_rng(addr, 16'hC000, 16'hCFFF);

        main_c = inh_i && !mpon && !suppressed && !sel_aux;
        aux_c  = inh_i && !mpon && !suppressed &&  sel_aux;
        exp_ramen_n = !main_c;
        exp_en80_n  = !aux_c;

        int_rom = 1'b0;
        if (f_rng(addr, 16'hC000, 16'hC0FF))
            int_rom = 1'b0;
        else if (f_rng(addr, 16'hC300, 16'hC3FF))
            int_rom = !r_slotc3;                 // C3 rule precedes the C1-7 rule
        else if (f_rng(addr, 16'hC100, 16'hC7FF))
            int_rom = r_intcx;
        else if (f_rng(addr, 16'hC800, 16'hCFFF))
            int_rom = r_intcx && r_c8win;

        exp_rom1_n = !inh_i ? 1'b1
                   : !(((r_rdram == 0) && rw_i && f_rng(addr, 16'hD000, 16'hDFFF))
                       || (int_rom && !f_rng(addr, 16'hC000, 16'hC0FF)));
        exp_rom2_n = !inh_i ? 1'b1
                   : !((r_rdram == 0) && rw_i && f_rng(addr, 16'hE000, 16'hFFFF));

        exp_cxxx  = f_rng(addr, 16'hC000, 16'hCFFF) && !int_rom;
        exp_kbd_n = !(rw_i && (f_rng(addr, 16'hC000, 16'hC00F)
                               || f_rng(addr, 16'hC010, 16'hC01F)));

        exp_md7_oe = rw_i && f_rng(addr, 16'hC011, 16'hC018);
        exp_md7 = 1'b0;
        if (exp_md7_oe) begin
            case (addr[3:0])
                4'h1: exp_md7 = r_bank2;
                4'h2: exp_md7 = r_rdram;
                4'h3: exp_md7 = r_ramrd;
                4'h4: exp_md7 = r_ramwrt;
                4'h5: exp_md7 = r_intcx;
                4'h6: exp_md7 = r_altzp;
                4'h7: exp_md7 = r_slotc3;
                4'h8: exp_md7 = r_store80;
                default: exp_md7 = 1'b0;
            endcase
        end

        exp_rw245 = !dma_i || !rw_i || f_rng(addr, 16'hC020, 16'hC0FF);

        m12 = (f_rng(addr, 16'hD000, 16'hDFFF) && (r_bank2 == 1'b0)) ^ addr[12];
        if (pras_i)
            exp_ra = {addr[8], addr[7], addr[5], addr[4], addr[3],
                      addr[2], addr[1], addr[0]};
        else
            exp_ra = {addr[15], addr[14], addr[13], m12, addr[11],
                      addr[10], addr[6], addr[9]};

        check(ramen_n  === exp_ramen_n,  "ramen_n");
        check(en80_n   === exp_en80_n,   "en80_n");
        check(romen1_n === exp_rom1_n,   "romen1_n");
        check(romen2_n === exp_rom2_n,   "romen2_n");
        check(cxxxout  === exp_cxxx,     "cxxxout");
        check(kbd_n    === exp_kbd_n,    "kbd_n");
        check(md7_oe   === exp_md7_oe,   "md7_oe");
        if (exp_md7_oe) check(md7 === exp_md7, "md7 value");
        check(rw245    === exp_rw245,    "rw245");
        check(ra       === exp_ra,       "ra");
    endtask

    // Reference state update for the presented access (same edge as the DUT).
    task automatic ref_update(input bit [15:0] addr, input bit rw_i);
        bit mpon_n, wren_n;

        // MPON uses the shift history BEFORE this access.
        mpon_n = (addr == 16'hFFFC) && r_s1 && r_s2 && r_s3;

        r_s3 = r_s2; r_s2 = r_s1; r_s1 = f_rng(addr, 16'h0100, 16'h01FF);

        if (mpon_n) begin
            // The DUT shift register keeps shifting through MPON; reset only
            // the soft-switch flags here.
            r_store80 = 0; r_ramrd = 0; r_ramwrt = 0;
            r_intcx = 0; r_altzp = 0; r_slotc3 = 0;
            r_pg2 = 0; r_hires = 0;
            r_bank2 = 1; r_rdram = 0; r_wren = 1; r_fst = 0; r_c8win = 0;
        end else begin
            if (f_rng(addr, 16'hC000, 16'hC00F) && !rw_i) begin
                case (addr[3:1])
                    3'd0: r_store80 = addr[0];
                    3'd1: r_ramrd   = addr[0];
                    3'd2: r_ramwrt  = addr[0];
                    3'd3: r_intcx   = addr[0];
                    3'd4: r_altzp   = addr[0];
                    3'd5: r_slotc3  = addr[0];
                    default: ;   // $C00C-$C00F: not MMU-observable
                endcase
            end
            if (f_rng(addr, 16'hC050, 16'hC05F) && !rw_i) begin
                case (addr[2:1])
                    2'd2: r_pg2   = addr[0];
                    2'd3: r_hires = addr[0];
                    default: ;
                endcase
            end
            if (f_rng(addr, 16'hC080, 16'hC08F)) begin
                wren_n  = addr[0] ? ((rw_i && r_fst) || r_wren) : 1'b0;
                r_bank2 = !addr[3];
                r_rdram = !(addr[0] ^ addr[1]);
                r_fst   = addr[0] && rw_i;
                r_wren  = wren_n;
            end
            if (f_rng(addr, 16'hC300, 16'hC3FF) && !r_slotc3)
                r_c8win = 1'b1;
            else if (addr == 16'hCFFF)
                r_c8win = 1'b0;
        end
    endtask

    // ------------------------------------------------------------------
    // Bus access: drive, check outputs, commit state at the rising edge
    // ------------------------------------------------------------------
    task automatic access(input bit [15:0] addr, input bit rw_i,
                          input bit pras_i = 1'b1, input bit inh_i = 1'b1,
                          input bit dma_i = 1'b1);
        begin
            @(negedge clk);
            a = addr; rw = rw_i; pras_n = pras_i; inh_n = inh_i; dma_n = dma_i;
            #(TCK/4);
            ref_compute(addr, rw_i, inh_i, dma_i, pras_i);   // driven phase
            cap_md7 = md7;
            cap_ra = ra;
            pras_n = ~pras_i;
            #(TCK/8);
            ref_compute(addr, rw_i, inh_i, dma_i, ~pras_i);  // opposite phase
            @(posedge clk);
            #(TCK/8);
            ref_update(addr, rw_i);
            if ($test$plusargs("trace"))
                $display("ACC %0t a=%h rw=%b | DUT s80=%b rrd=%b rwr=%b xcx=%b zpx=%b c3=%b p2=%b hr=%b b2=%b rdr=%b wr=%b fst=%b w8=%b | REF s80=%b rrd=%b rwr=%b xcx=%b zpx=%b c3=%b p2=%b hr=%b b2=%b rdr=%b wr=%b fst=%b w8=%b",
                         $time, a, rw,
                         dut.store80, dut.ramrd, dut.ramwrt, dut.intcx, dut.altzp,
                         dut.slotc3, dut.pg2, dut.hires, dut.bank2, dut.rdram,
                         dut.wren, dut.fst_acc, dut.c8win,
                         r_store80, r_ramrd, r_ramwrt, r_intcx, r_altzp,
                         r_slotc3, r_pg2, r_hires, r_bank2, r_rdram,
                         r_wren, r_fst, r_c8win);
        end
    endtask

    task automatic reset_chip;
        @(negedge clk);
        rst_n = 1'b0;
        a = 16'h0000; rw = 1'b1; pras_n = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        ref_reset_state();
        #(TCK/4);
    endtask

    // Flag readback: bus bit 7 seen while reading $C011-$C018.
    task automatic flag_read(input bit [15:0] flag_addr, output bit value);
        access(flag_addr, 1'b1);
        value = cap_md7;
    endtask

    task automatic switch_write(input bit [15:0] addr);
        access(addr, 1'b0);
    endtask

    // ------------------------------------------------------------------
    // Tests
    // ------------------------------------------------------------------
    bit v;

    initial begin
        $display("=== Apple IIe MMU testbench start ===");

        // ----------------------------------------------------------------
        // 1. Reset state (rst_n path) via the flag readbacks and mapping.
        // ----------------------------------------------------------------
        reset_chip();
        flag_read(16'hC011, v); check(v === 1'b1, "reset: bank2");
        flag_read(16'hC012, v); check(v === 1'b0, "reset: read ROM");
        flag_read(16'hC013, v); check(v === 1'b0, "reset: RAMRD off");
        flag_read(16'hC014, v); check(v === 1'b0, "reset: RAMWRT off");
        flag_read(16'hC015, v); check(v === 1'b0, "reset: slot Cx ROM");
        flag_read(16'hC016, v); check(v === 1'b0, "reset: ALTZP off");
        flag_read(16'hC017, v); check(v === 1'b0, "reset: internal C3");
        flag_read(16'hC018, v); check(v === 1'b0, "reset: 80STORE off");
        // RAM read below $C000 hits the main array; ROM reads in D-F.
        access(16'h1000, 1'b1);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "reset map: main RAM read");
        access(16'hD000, 1'b1);
        check(romen1_n === 1'b0 && romen2_n === 1'b1 && ramen_n === 1'b1,
              "reset map: D-ROM via ROMEN1");
        access(16'hE000, 1'b1);
        check(romen2_n === 1'b0 && romen1_n === 1'b1 && ramen_n === 1'b1,
              "reset map: E-ROM via ROMEN2");
        access(16'hC100, 1'b1);
        check(cxxxout === 1'b1 && romen1_n === 1'b1, "reset map: C100 slot ROM");

        // ----------------------------------------------------------------
        // 2. Switch matrix: each pair toggles only its flag.
        // ----------------------------------------------------------------
        switch_write(16'hC001); flag_read(16'hC018, v); check(v === 1'b1, "80STORE on");
        switch_write(16'hC000); flag_read(16'hC018, v); check(v === 1'b0, "80STORE off");
        switch_write(16'hC003); flag_read(16'hC013, v); check(v === 1'b1, "RAMRD on");
        switch_write(16'hC002); flag_read(16'hC013, v); check(v === 1'b0, "RAMRD off");
        switch_write(16'hC005); flag_read(16'hC014, v); check(v === 1'b1, "RAMWRT on");
        switch_write(16'hC004); flag_read(16'hC014, v); check(v === 1'b0, "RAMWRT off");
        switch_write(16'hC007); flag_read(16'hC015, v); check(v === 1'b1, "INTCXROM on");
        switch_write(16'hC006); flag_read(16'hC015, v); check(v === 1'b0, "INTCXROM off");
        switch_write(16'hC009); flag_read(16'hC016, v); check(v === 1'b1, "ALTZP on");
        switch_write(16'hC008); flag_read(16'hC016, v); check(v === 1'b0, "ALTZP off");
        switch_write(16'hC00B); flag_read(16'hC017, v); check(v === 1'b1, "SLOTC3ROM on");
        switch_write(16'hC00A); flag_read(16'hC017, v); check(v === 1'b0, "SLOTC3ROM off");
        // A RAMRD write must not disturb RAMWRT (latch address bits).
        switch_write(16'hC003);
        flag_read(16'hC014, v); check(v === 1'b0, "RAMRD write leaves RAMWRT");
        switch_write(16'hC002);
        // $C00C-$C00F are latched by the real part but MMU-unobservable (A8).
        switch_write(16'hC00D);
        switch_write(16'hC00F);
        flag_read(16'hC013, v); check(v === 1'b0, "C00C-F writes leave flags alone");

        // ----------------------------------------------------------------
        // 3. Language-card prewrite dances (Table 4-6 + prewrite rule).
        // ----------------------------------------------------------------
        // From reset (write enabled) an even access protects.
        switch_write(16'hC082); // read ROM, write protect, bank 2
        flag_read(16'hC012, v); check(v === 1'b0, "C082: read ROM");
        access(16'hD400, 1'b0); // write to the LC window
        check(ramen_n === 1'b1 && en80_n === 1'b1, "protected LC write discarded");
        // Two consecutive odd reads enable writes (bank 2).
        access(16'hC083, 1'b1);
        access(16'hC083, 1'b1);
        flag_read(16'hC012, v); check(v === 1'b1, "C083 double read: read RAM");
        access(16'hD400, 1'b0);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "enabled LC write hits main LC");
        // An odd write preserves the (protected) state and never enables.
        switch_write(16'hC08A); // protect, bank 1, read ROM
        access(16'hC089, 1'b1); // odd read sets the prewrite flag
        access(16'hC089, 1'b0); // odd write: state preserved, still protected
        flag_read(16'hC011, v); check(v === 1'b0, "C089: bank 1");
        flag_read(16'hC012, v); check(v === 1'b0, "C089: read ROM");
        access(16'hD400, 1'b0);
        check(ramen_n === 1'b1 && en80_n === 1'b1, "odd write did not enable");
        // The intervening write cleared the prewrite flag, so it takes two
        // more odd reads to enable.
        access(16'hC089, 1'b1);
        access(16'hC089, 1'b1);
        access(16'hD400, 1'b0);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "double odd read enables bank1");
        // Write-enable survives a bank switch made by an odd read.
        switch_write(16'hC08A);
        access(16'hC083, 1'b1);
        access(16'hC083, 1'b1); // enable, bank 2
        access(16'hC08B, 1'b1); // odd read, bank 1: wren preserved
        access(16'hD400, 1'b0);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "write survives odd-read bank switch");

        // ----------------------------------------------------------------
        // 4. Mapping matrix.
        // ----------------------------------------------------------------
        // Zero page / stack: ALTZP only.
        switch_write(16'hC002); switch_write(16'hC004); // RAMRD/RAMWRT off
        access(16'h0100, 1'b1);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "zp read main");
        switch_write(16'hC009);                          // ALTZP on
        access(16'h0100, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "zp read aux");
        access(16'h0100, 1'b0);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "zp write aux");
        switch_write(16'hC008);
        access(16'h0100, 1'b0);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "zp write main");

        // $0200-$BFFF: RAMRD/RAMWRT select independently per access direction.
        access(16'h1000, 1'b1);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "RAMRD off: read main");
        switch_write(16'hC003);
        access(16'h1000, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "RAMRD on: read aux");
        access(16'h1000, 1'b0);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "RAMWRT off: write main");
        switch_write(16'hC005);
        access(16'h1000, 1'b0);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "RAMWRT on: write aux");
        switch_write(16'hC002); switch_write(16'hC004);

        // Text page 1 under 80STORE/PAGE2.
        switch_write(16'hC001);                          // 80STORE on
        access(16'h0400, 1'b1);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "80STORE pg2 off: text main");
        switch_write(16'hC055);                          // PAGE2 on
        access(16'h0400, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "80STORE pg2: text aux read");
        access(16'h0400, 1'b0);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "80STORE pg2: text aux write");
        access(16'h1000, 1'b1);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "80STORE leaves non-page ranges");
        switch_write(16'hC054);

        // HIRES page 1 needs 80STORE and HIRES together.
        switch_write(16'hC057);                          // HIRES on
        access(16'h2000, 1'b1);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "80STORE+HIRES pg2 off: hires main");
        switch_write(16'hC055);
        access(16'h2000, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "80STORE+HIRES pg2: hires aux");
        access(16'h0400, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "HIRES keeps text page switch");
        access(16'h4000, 1'b1);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "hires switch ends at $3FFF");
        switch_write(16'hC056);                          // HIRES off
        switch_write(16'hC054);                          // PAGE2 off
        switch_write(16'hC000);                          // 80STORE off

        // $C000-$C0FF: I/O page, never RAM; CXXXOUT always asserted.
        access(16'hC030, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b1 && cxxxout === 1'b1,
              "I/O page: no RAM, CXXXOUT");
        check(kbd_n === 1'b1, "C030 read: keyboard buffer off");
        access(16'hC000, 1'b1);
        check(kbd_n === 1'b0, "C000 read: keyboard buffer on");
        access(16'hC010, 1'b0);
        check(kbd_n === 1'b1, "C010 write: keyboard read path off");

        // $C100-$C7FF slot vs internal ROM.
        access(16'hC200, 1'b1);
        check(cxxxout === 1'b1 && romen1_n === 1'b1, "C200: slot ROM space");
        switch_write(16'hC007);                          // internal Cx ROM
        access(16'hC200, 1'b1);
        check(cxxxout === 1'b0 && romen1_n === 1'b0, "C200: internal ROM");
        switch_write(16'hC006);                          // slots back

        // $C300 internal vs slot, and the C800 window lifecycle.
        access(16'hC300, 1'b1);
        check(cxxxout === 1'b0 && romen1_n === 1'b0, "C300: internal 80-col ROM");
        switch_write(16'hC00B);                          // slot C3
        access(16'hC300, 1'b1);
        check(cxxxout === 1'b1 && romen1_n === 1'b1, "C300: slot ROM");
        switch_write(16'hC00A);                          // internal C3
        switch_write(16'hC007);                          // internal Cx
        access(16'hC301, 1'b1);                          // opens the window
        access(16'hC900, 1'b1);
        check(cxxxout === 1'b0 && romen1_n === 1'b0, "C900: internal via window");
        access(16'hCFFF, 1'b1);                          // closes the window
        access(16'hC900, 1'b1);
        check(cxxxout === 1'b1, "C900 after CFFF: card space again");
        switch_write(16'hC006);                          // slots in Cx

        // $D000-$DFFF ROM reads vs banked RAM; $E000-$FFFF bank-independent.
        switch_write(16'hC082);                          // read ROM, bank 2
        access(16'hD800, 1'b1);
        check(romen1_n === 1'b0 && ramen_n === 1'b1 && en80_n === 1'b1,
              "D800 ROM read: ROMEN1 only");
        access(16'hF800, 1'b1);
        check(romen2_n === 1'b0 && romen1_n === 1'b1, "F800 ROM read: ROMEN2 only");
        switch_write(16'hC009);                          // ALTZP on: LC switches aux
        access(16'hC083, 1'b1);
        access(16'hC083, 1'b1);                          // read aux LC RAM
        access(16'hD000, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "ALTZP: D000 read hits aux LC");
        access(16'hF000, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "ALTZP: F000 read hits aux LC");
        switch_write(16'hC008);                          // ALTZP off
        access(16'hD000, 1'b1);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "ALTZP off: D000 back to main LC");

        // Column-phase RA4 (captured in the driven phase) inside the window:
        // a[12] is 1 throughout $D000-$DFFF, so bank 1 sends the window to
        // physical $C000-$CFFF (ma12=0) and bank 2 leaves it at $D000 (ma12=1).
        switch_write(16'hC08A);                          // bank 1, read ROM
        access(16'hD000, 1'b1, 1'b0);                    // column phase
        check(cap_ra[4] === 1'b0, "bank1 column RA4 remaps window to $Cxxx");
        access(16'hD800, 1'b1, 1'b0);
        check(cap_ra[4] === 1'b0, "bank1 column RA4 across the window");
        access(16'hE000, 1'b1, 1'b0);
        check(cap_ra[4] === a[12], "outside D window RA4 follows a12");
        switch_write(16'hC083);                          // bank 2 (write-protects)
        access(16'hD000, 1'b1, 1'b0);
        check(cap_ra[4] === 1'b1, "bank2 column RA4 stays at $Dxxx");

        // Row phase always carries the Table 7-9 row pattern.
        access(16'h1234, 1'b1, 1'b1);
        check(cap_ra === {a[8], a[7], a[5], a[4], a[3], a[2], a[1], a[0]}, "row RA pattern");

        // ----------------------------------------------------------------
        // 5. DMA and INH.
        // ----------------------------------------------------------------
        switch_write(16'hC002); switch_write(16'hC004);
        access(16'h1000, 1'b1, 1'b1, 1'b1, 1'b0);        // DMA asserted, read
        check(rw245 === 1'b1, "DMA read: bus toward MD");
        check(ramen_n === 1'b0 && en80_n === 1'b1, "DMA keeps mapping active");
        access(16'h1000, 1'b1, 1'b1, 1'b0, 1'b0);        // INH asserted
        check(ramen_n === 1'b1 && en80_n === 1'b1 && romen1_n === 1'b1
              && romen2_n === 1'b1, "INH drops all selects");

        // ----------------------------------------------------------------
        // 6. Historical sequences (TRM Appendix I Monitor listing).
        // ----------------------------------------------------------------
        // (a) Reset-time initialization: MPON bus sequence, then the
        //     monitor's switch writes (aux off, internal C3).
        switch_write(16'hC009); switch_write(16'hC003);  // dirty the state
        switch_write(16'hC001); switch_write(16'hC00A);
        access(16'hC301, 1'b1);                          // open window
        switch_write(16'hC00B);                          // dirty: slot C3
        access(16'h01FD, 1'b1);
        access(16'h01FC, 1'b1);
        access(16'h01FB, 1'b1);
        access(16'hFFFC, 1'b1);                          // MPON fires here
        flag_read(16'hC016, v); check(v === 1'b0, "MPON: ALTZP cleared");
        flag_read(16'hC013, v); check(v === 1'b0, "MPON: RAMRD cleared");
        flag_read(16'hC017, v); check(v === 1'b0, "MPON: internal C3");
        flag_read(16'hC011, v); check(v === 1'b1, "MPON: bank 2");
        access(16'hC900, 1'b1);
        check(cxxxout === 1'b1, "MPON: window closed");
        switch_write(16'hC00A);                          // monitor selects internal C3
        access(16'hC300, 1'b1);
        check(cxxxout === 1'b0, "monitor init: internal C3 serving");

        // (b) AUXMOVE-style byte copy main -> aux (TRM ch.4 subroutines).
        switch_write(16'hC003);                          // RAMRD on
        access(16'h6000, 1'b1);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "AUXMOVE: read aux");
        switch_write(16'hC005);                          // RAMWRT on
        access(16'h7000, 1'b0);
        check(ramen_n === 1'b1 && en80_n === 1'b0, "AUXMOVE: write aux");
        switch_write(16'hC002); switch_write(16'hC004);  // restore
        access(16'h7000, 1'b0);
        check(ramen_n === 1'b0 && en80_n === 1'b1, "AUXMOVE: restored main");

        // (c) RESETRET slot-3 ROM probe dance (TRM listing): swap in slot 3,
        //     probe, fall back to internal when no card answers.
        switch_write(16'hC00B);                          // SETSLOTC3ROM
        access(16'hC300, 1'b1);
        check(cxxxout === 1'b1 && romen1_n === 1'b1, "RESETRET: slot C3 probed");
        switch_write(16'hC00A);                          // SETINTC3ROM fallback
        access(16'hC300, 1'b1);
        check(cxxxout === 1'b0 && romen1_n === 1'b0, "RESETRET: internal fallback");

        // ----------------------------------------------------------------
        // 7. Random soak against the reference model.
        // ----------------------------------------------------------------
        begin
            int n;
            bit [15:0] ra_addr;
            bit rw_bit, pras_bit;
            for (n = 0; n < 3000; n++) begin
                case ($urandom_range(0, 9))
                    0: ra_addr = 16'($urandom_range(0, 16'h0FF));
                    1: ra_addr = 16'($urandom_range(0, 3) << 4) | 16'hC050;
                    2: ra_addr = 16'($urandom_range(0, 16'h0F)) | 16'hC080;
                    3: ra_addr = 16'($urandom_range(0, 16'h6FF)) | 16'hC100;
                    4: ra_addr = 16'($urandom_range(0, 16'hFFF)) | 16'hD000;
                    5: ra_addr = 16'($urandom_range(0, 16'h1FFF)) | 16'hE000;
                    6: ra_addr = 16'($urandom_range(0, 16'h01FF));
                    7: ra_addr = 16'($urandom_range(0, 16'hFF)) | 16'h0100;
                    8: ra_addr = 16'hFFFC;
                    default: ra_addr = 16'($urandom_range(0, 16'hBFFF));
                endcase
                rw_bit   = 1'($urandom_range(0, 1));
                pras_bit = 1'($urandom_range(0, 1));
                access(ra_addr, rw_bit, pras_bit);
            end
        end

        // ----------------------------------------------------------------
        if (errors == 0)
            $display("Apple IIe MMU TEST PASSED checks=%0d", checks);
        else
            $fatal(1, "Apple IIe MMU TEST FAILED errors=%0d checks=%0d", errors, checks);
        $finish;
    end

    // Watchdog
    initial begin
        #20_000_000;
        $fatal(1, "Apple IIe MMU TEST TIMEOUT");
    end
endmodule
