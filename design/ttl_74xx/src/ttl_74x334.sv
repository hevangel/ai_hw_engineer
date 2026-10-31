// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x334.md.
// ttl_74x334 - PLA (12 inputs, 32 terms, 6 outputs).
module ttl_74x334 #(parameter AND_FILE = "", parameter OR_FILE = "")
(
    input  logic [11:0] in,
    output logic [5:0]  out
);
    logic [23:0] term_masks [0:31];
    logic [31:0] or_masks   [0:5];
    logic [31:0] terms;
    initial begin
        if (AND_FILE != "") $readmemb(AND_FILE, term_masks);
        else for (int i = 0; i < 32; i++) term_masks[i] = 24'h0;
        if (OR_FILE != "") $readmemb(OR_FILE, or_masks);
        else for (int i = 0; i < 6; i++) or_masks[i] = 32'h0;
    end
    always_comb begin
        for (int t = 0; t < 32; t++) begin
            logic [11:0] inc_mask, cmpl_mask;
            inc_mask  = term_masks[t][11:0];
            cmpl_mask = term_masks[t][23:12];
            terms[t]  = &(~(inc_mask & ~in) & ~(cmpl_mask & in));
            if (inc_mask == 12'h0 && cmpl_mask == 12'h0) terms[t] = 1'b0;
        end
        for (int o = 0; o < 6; o++) out[o] = |(terms & or_masks[o]);
    end
endmodule
