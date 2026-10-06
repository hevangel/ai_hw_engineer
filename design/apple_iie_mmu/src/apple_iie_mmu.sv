`timescale 1ns/1ps
// Apple IIe MMU (Apple 341-0266) - functional reconstruction.
//
// Single-clock synchronous model: clk corresponds to CPU phase 0 (PHI_0) and
// one bus access (a, rw) is presented per rising edge. Soft-switch state is
// registered; mapping outputs are combinational functions of the presented
// access and the registered state, matching the real chip at bus-cycle
// granularity. Pin 4 (Q3) is a DRAM-timing input with no functional effect
// and is omitted; see spec/spec.md for the source-anchored behavior and the
// assumption ledger.

module apple_iie_mmu (
    input  logic        clk,       // PH0; posedge = access boundary
    input  logic        rst_n,     // synchronous reset (MPON-equivalent; not a chip pin)
    input  logic [15:0] a,         // 6502 address bus (pins 2, 26-40)
    input  logic        rw,        // CPU R/W' (pin 14); 1 = read
    input  logic        pras_n,    // PRAS' from PAL (pin 5); row-address strobe
    input  logic        inh_n,     // INH' (pin 15); tied high on the IIe
    input  logic        dma_n,     // DMA' (pin 16)
    output logic [7:0]  ra,        // RA0-RA7 (pins 6-13); multiplexed RAM address
    output logic        ramen_n,   // RAMEN'/CASEN (pin 23); main array cycle enable
    output logic        en80_n,    // EN80' (pin 17); auxiliary array cycle enable
    output logic        romen1_n,  // ROMEN1' (pin 20); D000-DFFF ROM + internal Cxxx ROM
    output logic        romen2_n,  // ROMEN2' (pin 19); E000-FFFF ROM reads
    output logic        cxxxout,   // C0XX (pin 24); active high: $Cxxx not served by internal ROM
    output logic        kbd_n,     // KBD' (pin 18); keyboard buffer enable
    output logic        md7,       // MD7 (pin 21); switch flag onto bus bit 7
    output logic        md7_oe,    // MD7 drive enable (tri-state equivalent)
    output logic        rw245      // RW245 (pin 22); 1 = CPU-side bus drives MD
);

    // ------------------------------------------------------------------
    // Address decode
    // ------------------------------------------------------------------
    logic in_cxxx, in_d, in_df, in_ef, zp_stack, textpg1, hirespg1;
    logic access_c0xx, access_c00x, access_c01x, access_c05x, access_c08x;
    logic access_c3xx, access_intc3, a01xx, a_fffc;

    assign in_cxxx    = (a[15:12] == 4'hC);              // $C000-$CFFF page
    assign in_d       = (a[15:12] == 4'hD);              // $D000-$DFFF
    assign in_df      = in_d || (a[15:13] == 3'b111);    // $D000-$FFFF
    assign in_ef      = (a[15:13] == 3'b111);            // $E000-$FFFF
    assign zp_stack   = (a[15:9]  == 7'h0);              // $0000-$01FF
    assign textpg1    = (a[15:10] == 6'h01);             // $0400-$07FF
    assign hirespg1   = (a[15:13] == 3'b001);            // $2000-$3FFF

    assign access_c0xx  = (a[15:8] == 8'hC0);            // $C000-$C0FF
    assign access_c00x  = access_c0xx && (a[7:4] == 4'h0);
    assign access_c01x  = access_c0xx && (a[7:4] == 4'h1);
    assign access_c05x  = access_c0xx && (a[7:4] == 4'h5);
    assign access_c08x  = access_c0xx && (a[7:4] == 4'h8);
    assign access_c3xx  = (a[15:8] == 8'hC3);            // $C300-$C3FF
    assign a01xx        = (a[15:8] == 8'h01);            // $0100-$01FF
    assign a_fffc       = (a == 16'hFFFC);

    // ------------------------------------------------------------------
    // Soft-switch state
    // ------------------------------------------------------------------
    logic store80, ramrd, ramwrt, intcx, altzp, slotc3;  // $C00x latch (Q0..Q5)
    logic pg2, hires;                                    // $C05x (74LS259)
    logic bank2, rdram, wren, fst_acc;                   // $C08x language card (LS175)
    logic c8win;                                         // internal $C800-$CFFF window
    logic s1_01xx, s2_01xx, s3_01xx;                     // MPON shift register

    // MPON: the 6502 reset sequence - stack reads at $01xx, then $FFFC.
    logic mpon;
    assign mpon = a_fffc && s1_01xx && s2_01xx && s3_01xx;

    logic intc3_sel;                     // internal ROM selected at $C300
    assign intc3_sel = !slotc3;
    assign access_intc3 = access_c3xx && intc3_sel;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // TRM reset state; matches the LS175/9334/259 clear values on MPON.
            store80 <= 1'b0;
            ramrd   <= 1'b0;
            ramwrt  <= 1'b0;
            intcx   <= 1'b0;    // slot ROMs in $C100-$C7FF
            altzp   <= 1'b0;
            slotc3  <= 1'b0;    // internal ROM at $C300
            pg2     <= 1'b0;
            hires   <= 1'b0;
            bank2   <= 1'b1;    // $D000 bank 2
            rdram   <= 1'b0;    // read ROM
            wren    <= 1'b1;    // write enabled
            fst_acc <= 1'b0;
            c8win   <= 1'b0;
            s1_01xx <= 1'b0;
            s2_01xx <= 1'b0;
            s3_01xx <= 1'b0;
        end else begin
            s1_01xx <= a01xx;
            s2_01xx <= s1_01xx;
            s3_01xx <= s2_01xx;

            if (mpon) begin
                // Hardware reset detection forces the power-on switch state.
                store80 <= 1'b0;
                ramrd   <= 1'b0;
                ramwrt  <= 1'b0;
                intcx   <= 1'b0;
                altzp   <= 1'b0;
                slotc3  <= 1'b0;
                pg2     <= 1'b0;
                hires   <= 1'b0;
                bank2   <= 1'b1;
                rdram   <= 1'b0;
                wren    <= 1'b1;
                fst_acc <= 1'b0;
                c8win   <= 1'b0;
            end else begin
                // $C00x latch: addressed by a[3:1], data bit a[0], writes only.
                if (access_c00x && !rw) begin
                    case (a[3:1])
                        3'd0: store80 <= a[0];
                        3'd1: ramrd   <= a[0];
                        3'd2: ramwrt  <= a[0];
                        3'd3: intcx   <= a[0];
                        3'd4: altzp   <= a[0];
                        3'd5: slotc3  <= a[0];
                        default: ;   // $C00C-$C00F: IOU-shared, no MMU-observable effect (A8)
                    endcase
                end
                // $C05x latch: PAGE2 ($C054/5) and HIRES ($C056/7), writes only;
                // the 259 select is a[2:1] with data bit a[0].
                if (access_c05x && !rw) begin
                    case (a[2:1])
                        2'd2: pg2   <= a[0];
                        2'd3: hires <= a[0];
                        default: ;   // ITEXT, MIXED, AN0-3 belong to the IOU
                    endcase
                end
                // $C08x language-card register: every access updates the LS175.
                if (access_c08x) begin
                    bank2   <= !a[3];
                    rdram   <= !(a[0] ^ a[1]);
                    fst_acc <= a[0] && rw;
                    // Prewrite rule: an even address write-protects; an odd
                    // address keeps the enable only via the double-odd-read
                    // dance (spec, Sather 5-23).
                    wren    <= a[0] ? ((rw && fst_acc) || wren) : 1'b0;
                end
                // Expansion window: opened by internal $C3, closed by $CFFF.
                if (access_intc3) begin
                    c8win <= 1'b1;
                end else if (a == 16'hCFFF) begin
                    c8win <= 1'b0;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Array selection
    // ------------------------------------------------------------------
    logic rdrom;
    assign rdrom = !rdram;

    // No RAM cycle for ROM reads in $D000-$FFFF, nor for write-protected
    // language-card writes, nor anywhere in $Cxxx (PCASEN terms).
    logic ram_suppressed;
    assign ram_suppressed = (rdrom && in_df && rw)
                          || (!wren && in_df && !rw)
                          || in_cxxx;

    // SELMB priority: video pages under 80STORE, then ALTZP ranges, then
    // RAMRD/RAMWRT (spec; Sather p.5-25 ordering).
    logic sel_aux;
    always_comb begin
        if ((textpg1 && store80) || (hirespg1 && hires && store80))
            sel_aux = pg2;
        else if (in_df || zp_stack)
            sel_aux = altzp;
        else
            sel_aux = rw ? ramrd : ramwrt;
    end

    // INH' and MPON hold every array select off; ROM is held off by INH' only.
    logic inh_off, inh_rom;
    assign inh_off = !inh_n || mpon;
    assign inh_rom = !inh_n;

    logic main_cycle, aux_cycle;
    assign main_cycle = !inh_off && !ram_suppressed && !sel_aux;
    assign aux_cycle  = !inh_off && !ram_suppressed &&  sel_aux;

    assign ramen_n = !main_cycle;
    assign en80_n  = !aux_cycle;

    // ------------------------------------------------------------------
    // ROM decode
    // ------------------------------------------------------------------
    logic in_c1_7, in_c8_f, cxxx_internal;
    logic rom_d_read, rom_ef_read;

    assign in_c1_7  = in_cxxx && !a[11] && (a[10] || a[9] || a[8]);  // $C100-$C7FF
    assign in_c8_f  = in_cxxx && a[11];                              // $C800-$CFFF

    // Internal service in $Cxxx: intcx-selected $C100-$CFFF (window-gated at
    // $C800-$CFFF), internal $C300. The $C300 rule wins over the $C100-$C7FF
    // rule ($C300 lies inside that range); $C000-$C0FF is never ROM.
    always_comb begin
        if (access_c0xx)
            cxxx_internal = 1'b0;
        else if (access_c3xx)
            cxxx_internal = intc3_sel;
        else if (in_c1_7)
            cxxx_internal = intcx;
        else if (in_c8_f)
            cxxx_internal = intcx && c8win;
        else
            cxxx_internal = 1'b0;
    end

    assign rom_d_read  = rdrom && rw && in_d;    // ROMEN1' $D000-$DFFF term
    assign rom_ef_read = rdrom && rw && in_ef;   // ROMEN2' $E000-$FFFF term

    // ROMEN1' is read-qualified for the $D000-$DFFF ROM but not for internal
    // $Cxxx service (matches the real equations); ROMEN2' is read-qualified.
    assign romen1_n = inh_rom ? 1'b1 : !(rom_d_read || cxxx_internal);
    assign romen2_n = inh_rom ? 1'b1 : !rom_ef_read;

    assign cxxxout = in_cxxx && !cxxx_internal;

    // ------------------------------------------------------------------
    // RA multiplexer (TRM Table 7-9) with the $D000-$DFFF interleave
    // ------------------------------------------------------------------
    logic ma12;
    logic [7:0] row_addr, col_addr;

    // Physical bit 12 inside $D000-$DFFF: bank 1 flips it, sending the
    // window to physical $C000-$CFFF; bank 2 leaves it at $D000-$DFFF.
    assign ma12 = (in_d && !bank2) ^ a[12];
    assign row_addr = {a[8], a[7], a[5], a[4], a[3], a[2], a[1], a[0]};
    assign col_addr = {a[15], a[14], a[13], ma12, a[11], a[10], a[6], a[9]};
    assign ra = pras_n ? row_addr : col_addr;

    // ------------------------------------------------------------------
    // CXXXOUT, KBD', RW245, MD7
    // ------------------------------------------------------------------
    logic in_c020_c0ff;
    assign in_c020_c0ff = access_c0xx && (a[7:4] != 4'h0) && (a[7:4] != 4'h1);

    assign kbd_n = !(rw && (access_c00x || access_c01x));

    // MD7 drives bus bit 7 on reads of $C011-$C018 (a[3:0] = 1..8).
    logic md7_sel;
    assign md7_sel = rw && access_c01x && (a[3:0] >= 4'h1) && (a[3:0] <= 4'h8);

    always_comb begin
        case (a[3:0])
            4'h1:    md7 = bank2;
            4'h2:    md7 = rdram;
            4'h3:    md7 = ramrd;
            4'h4:    md7 = ramwrt;
            4'h5:    md7 = intcx;
            4'h6:    md7 = altzp;
            4'h7:    md7 = slotc3;
            4'h8:    md7 = store80;
            default: md7 = 1'b0;
        endcase
    end
    assign md7_oe = md7_sel;

    // RW245: CPU bus toward MD during DMA, writes, and $C020-$C0FF reads.
    assign rw245 = !dma_n || !rw || in_c020_c0ff;

`ifdef FORMAL
    `include "apple_iie_mmu_props.sv"
    `include "apple_iie_mmu_cover_setup.sv"
`endif
endmodule
