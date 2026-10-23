// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2961.md.
// ttl_74x2961 - 4-bit EDAC bus buffer, inverting (Am2961-equivalent).
// 4-bit bidirectional buffer for use with the 2960 EDAC.  Each direction
// (system bus <-> memory bus) has its own active-low output enable.
module ttl_74x2961 (
    input  logic       oe_sm_n,   // enable system-side to memory-side path
    input  logic       oe_ms_n,   // enable memory-side to system-side path
    input  logic [3:0] sys_in,
    input  logic [3:0] mem_in,
    output logic [3:0] sys_out,
    output logic [3:0] mem_out
);
    assign mem_out = !oe_sm_n ? ~sys_in : 4'b0;
    assign sys_out = !oe_ms_n ? ~mem_in : 4'b0;
endmodule
