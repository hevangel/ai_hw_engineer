// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x700.md.
// ttl_74x700 - octal dRAM driver, inverting (3-state).
//
// Logically equivalent to 74x240: two 4-bit halves each gated by an
// active-low output enable, outputs are the bitwise complement of the
// inputs. The 'S700 differs from '240 in physical drive characteristics
// (impedance-matched for DRAM address lines); that physical behavior is
// not modeled here.
module ttl_74x700 (
    input  logic [7:0] a,
    input  logic       oe1_n, oe2_n,
    output logic [7:0] y
);
    assign y[3:0] = oe1_n ? 4'h0 : ~a[3:0];
    assign y[7:4] = oe2_n ? 4'h0 : ~a[7:4];
endmodule
