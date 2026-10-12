// Apple IIe timing PAL (PAL16R8) — functional reconstruction.
// One clk14 edge = one 14M tick; one CPU cycle = 14 ticks (spec 4).
// All outputs are registered macrocells decoding the tick being entered,
// exactly like the PAL's flip-flops plus AND-OR array.
// All behavior per spec/spec.md; ASSUMPTION markers reference its ledger.
`timescale 1ns/1ps

module apple_iie_pal (
    input  logic clk14,      // pin 1: 14.31818 MHz master oscillator
    input  logic rst_n,      // repo convention chip reset (spec 5)
    // inputs (pins 2, 8, 9, 11 — the pins the reconstruction's equations
    // consume; the part's pins 3-7 exist but their effects are inside the
    // unreconstructed gating, spec A5/A6)
    input  logic m7,         // 7M, made on the board (÷2 of 14M)
    input  logic ramen_n,    // RAM enable (CAS enable) — gates PCAS'
    input  logic s80vid_n,   // 80-column video enable — LDPS' cadence
    input  logic entmg_n,    // enable master timing (A6)
    // outputs (pins 12-17, 19)
    output logic ldps_n,     // video shift-register load enable
    output logic vid7m,      // video dot clock (7 MHz rate)
    output logic phi1,       // phase 1 system clock
    output logic phi0,       // phase 0 system clock
    output logic q3,         // intermediate timing/strobe
    output logic pcas_n,     // RAM column-address strobe
    output logic pras_n      // RAM row-address strobe
);

    // ------------------------------------------------------------------
    // Tick counter: 0..13, tick 0 = the phi0 window (spec 4, A2/A8)
    // ------------------------------------------------------------------
    logic [3:0] tick_q;
    logic       run;
    assign run = rst_n && entmg_n;

    logic [3:0] tick_nxt;
    assign tick_nxt = (tick_q == 4'd13) ? 4'd0 : tick_q + 4'd1;

    // Decode functions of the tick being ENTERED (spec 4).
    logic d_phi0, d_q3, d_prasn;
    assign d_phi0  = (tick_nxt < 4'd7);
    assign d_q3    = ((tick_nxt >= 4'd7 ? tick_nxt - 4'd7 : tick_nxt) < 4'd4);
    assign d_prasn = (tick_nxt < 4'd4);

    // PCAS': high ticks 0-5, falls at tick 6 unless the cycle is gated by
    // RAMEN' (sampled entering tick 5, sticky for the cycle, A7), high at
    // 13 and from tick 0.
    logic cas_gated_q, cas_gated_nxt;
    logic d_pcasn;
    always_comb begin
        cas_gated_nxt = cas_gated_q;
        if (tick_nxt == 4'd5) begin
            cas_gated_nxt = ramen_n;              // sample for this cycle
            d_pcasn       = 1'b1;                 // falls at 6, not 5
        end else if (tick_nxt == 4'd0) begin
            cas_gated_nxt = 1'b0;
            d_pcasn       = 1'b1;
        end else if (tick_nxt == 4'd13 || tick_nxt <= 4'd5) begin
            d_pcasn       = 1'b1;
        end else begin                            // ticks 6-12
            d_pcasn       = cas_gated_q;          // 1 = gated: stay high
        end
    end

    // LDPS': 1-tick pulses entering ticks 6 and 13; tick 6 only in
    // 80-column (s80vid_n = 0) (spec 4.3, A4)
    logic d_ldpsn;
    assign d_ldpsn = !((tick_nxt == 4'd13)
                       || ((tick_nxt == 4'd6) && !s80vid_n));

    logic r_phi0, r_q3, r_prasn, r_pcasn, r_ldpsn, r_vid7m;

    always_ff @(posedge clk14) begin
        if (!run) begin
            tick_q      <= 4'd0;
            r_phi0      <= 1'b0;
            r_q3        <= 1'b0;
            r_prasn     <= 1'b1;
            r_pcasn     <= 1'b1;
            r_ldpsn     <= 1'b1;
            r_vid7m     <= 1'b0;
            cas_gated_q <= 1'b0;
        end else begin
            tick_q      <= tick_nxt;
            r_phi0      <= d_phi0;
            r_q3        <= d_q3;
            r_prasn     <= d_prasn;
            r_pcasn     <= d_pcasn;
            r_ldpsn     <= d_ldpsn;
            r_vid7m     <= m7;
            cas_gated_q <= cas_gated_nxt;
        end
    end

    assign phi0   = r_phi0;
    assign phi1   = !r_phi0;
    assign q3     = r_q3;
    assign pras_n = r_prasn;
    assign pcas_n = r_pcasn;
    assign ldps_n = r_ldpsn;
    assign vid7m  = r_vid7m;

`ifdef FORMAL
    `include "apple_iie_pal_props.sv"
    `include "apple_iie_pal_cover_setup.sv"
`endif
endmodule
