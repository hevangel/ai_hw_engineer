// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74s416.md.
// ttl_74s416 - 4-bit bidirectional bus transceiver, non-inverting (Intel 8216).
module ttl_74s416 (
    input  logic       cs_n,
    input  logic       dir,        // 1=A->B, 0=B->A
    input  logic [3:0] a_in, b_in,
    output logic [3:0] a_out, b_out,
    output logic       a_oe_n, b_oe_n
);
    always_comb begin
        if (cs_n)      begin a_out=0; b_out=0; a_oe_n=1; b_oe_n=1; end
        else if (dir)  begin b_out=a_in; a_out=0; b_oe_n=0; a_oe_n=1; end
        else           begin a_out=b_in; b_out=0; a_oe_n=0; b_oe_n=1; end
    end
endmodule
