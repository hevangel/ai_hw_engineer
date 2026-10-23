// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x850.md.
// =============================================================================
// ttl_74x850 - 1-of-16 data selector/multiplexer, clocked select, 3-state
//
// Original part number : 74x850 (SN74AS850)
// Datasheet reference  : TI SN54AS850/851 (December 1983)
//
// Function
// --------
// A 16-to-1 multiplexer with complementary 3-state outputs Y and W. The 4-bit
// select (S3..S0) is captured by a clock-controlled register: on the rising
// edge of clk the select inputs are loaded; otherwise the previously loaded
// select is held. The selected data line drives Y; its complement drives W.
//
//   sel  : loaded from s on posedge clk (Input Selection Table)
//   data : d[sel]
//   Output Function Table:
//     /G=H            -> Y=Z,   W=Z
//     /G=L,/GY=L      -> Y=data
//     /G=L,/GY=H      -> Y=Z
//     /G=L,/GW=L      -> W=~data
//     /G=L,/GW=H      -> W=Z
//
// i.e.  Y = (!g_n && !gy_n) ? data : Z ;  W = (!g_n && !gw_n) ? ~data : Z
//
// High-Z is modeled as a driven 0 (library convention). The '851 is the
// enable-controlled (latched-select) sibling.
//
// FPGA notes
// ----------
// Clocked select register (posedge clk). 3-state modeled as muxed 0.
//
// Pin mapping (28-pin): D7..D0 = 1..8, /GY=9, /GW=10, /G=11, CLK=12, W=13,
// GND=14, S3..S0=15..18, Y=19, D15..D8=20..27, Vcc=28. (d[i]=Di, s[3]=S3.)
//
// Unsupported physical behavior
// -----------------------------
// True three-state high-Z (modeled as driven 0); electrical drive.
// =============================================================================

module ttl_74x850 (
    input  logic        clk,        // select-register clock (posedge loads s)
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

    always_ff @(posedge clk) sel <= s;     // clock-controlled select register

    assign data = d[sel];
    assign y = (!g_n && !gy_n) ?  data : 1'b0;
    assign w = (!g_n && !gw_n) ? ~data : 1'b0;
endmodule
