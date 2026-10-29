// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x800.md.
// ttl_74x800 - triple 4-input AND/NAND drivers.
// Three independent gates; each produces both AND (active-high) and NAND (active-low)
// outputs from the same 4 inputs. Per AS-family high-drive characteristics; physical
// drive strength is not modeled in RTL.
module ttl_74x800 (
    input  logic [3:0] a0, a1, a2,
    output logic       y0,    y1,    y2,
    output logic       y0_n,  y1_n,  y2_n
);
    assign y0   =  &a0;  assign y0_n = ~&a0;
    assign y1   =  &a1;  assign y1_n = ~&a1;
    assign y2   =  &a2;  assign y2_n = ~&a2;
endmodule
