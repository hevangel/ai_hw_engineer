// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x351.md.
// ttl_74x351 - Dual 8-to-1 mux with 4 common data inputs (D0-D3 shared).
// Each mux selects from 8 inputs, but D0-D3 are shared between both muxes.
// 4 dedicated inputs per mux (D4..D7).
module ttl_74x351 (
    input  logic [2:0] s,
    input  logic [3:0] d_common,
    input  logic [3:0] d0_extra,
    input  logic [3:0] d1_extra,
    input  logic [1:0] g_n,
    output logic [1:0] y
);
    logic [7:0] mux0, mux1;
    assign mux0 = {d0_extra, d_common};
    assign mux1 = {d1_extra, d_common};
    assign y[0] = g_n[0] ? 1'b0 : mux0[s];
    assign y[1] = g_n[1] ? 1'b0 : mux1[s];
endmodule
