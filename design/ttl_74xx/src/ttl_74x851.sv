// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x851.md.
// =============================================================================
// ttl_74x851 - 1-of-16 data selector/multiplexer, latched select, 3-state
//
// Original part number : 74x851 (SN74AS851)
// Datasheet reference  : TI SN54AS850/851 (December 1983)
//
// Function
// --------
// A 16-to-1 multiplexer with complementary 3-state outputs Y and W. The 4-bit
// select (S3..S0) passes through an enable-controlled latch: while sc_n is low
// the select is transparent (follows S3..S0); when sc_n is high the select is
// held (the input selected before the most-recent low-to-high SC transition).
//
//   sel  : transparent latch of s, enabled (transparent) when sc_n low
//   data : d[sel]
//   Y = (!g_n && !gy_n) ? data : Z ;  W = (!g_n && !gw_n) ? ~data : Z
//
// (Same Output Function Table as the '850; only the select register differs —
// the '850 is clock-controlled, the '851 is enable/latch-controlled.)
//
// High-Z is modeled as a driven 0 (library convention).
//
// FPGA notes
// ----------
// The select register is a transparent latch (the chip's actual behavior), so
// always_latch is used deliberately. 3-state modeled as muxed 0.
//
// Pin mapping (28-pin): D7..D0 = 1..8, /GY=9, /GW=10, /G=11, SC=12, W=13,
// GND=14, S3..S0=15..18, Y=19, D15..D8=20..27, Vcc=28. (d[i]=Di, s[3]=S3.)
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z (modeled as driven 0); electrical drive.
// =============================================================================

module ttl_74x851 (
    input  logic        sc_n,       // select control: low=transparent, high=hold
    input  logic [3:0]  s,          // select inputs S3..S0 (s[3]=S3 MSB)
    input  logic [15:0] d,          // data inputs D0..D15
    input  logic        g_n,        // master output control, active low
    input  logic        gy_n,       // Y output control, active low
    input  logic        gw_n,       // W output control, active low
    output logic        y,
    output logic        w
);
    logic [3:0] sel;
    logic       data;

    always_latch if (!sc_n) sel = s;       // transparent when sc_n low; else hold

    assign data = d[sel];
    assign y = (!g_n && !gy_n) ?  data : 1'b0;
    assign w = (!g_n && !gw_n) ? ~data : 1'b0;
endmodule
