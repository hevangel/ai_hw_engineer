// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2962.md.
// ttl_74x2962 - 4-bit EDAC bus buffer, non-inverting (Am2962-equivalent).
module ttl_74x2962 (
    input  logic       oe_sm_n,
    input  logic       oe_ms_n,
    input  logic [3:0] sys_in,
    input  logic [3:0] mem_in,
    output logic [3:0] sys_out,
    output logic [3:0] mem_out
);
    assign mem_out = !oe_sm_n ? sys_in : 4'b0;
    assign sys_out = !oe_ms_n ? mem_in : 4'b0;
endmodule
