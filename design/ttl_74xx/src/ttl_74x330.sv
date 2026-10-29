// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x330.md.
// ttl_74x330 - Programmable logic array (PLA): 12 inputs, 50 terms, 6 outputs.
// Default unprogrammed state outputs all zeros. To program, override the
// AND_FILE (input/complement masks per term) and OR_FILE (output mask per term)
// parameters with $readmemb-formatted files.
module ttl_74x330 #(parameter AND_FILE = "", parameter OR_FILE = "")
(
    input  logic [11:0] in,
    output logic [5:0]  out
);
    // Each term has a 24-bit mask: 12 bits for "include input" and 12 bits
    // for "include complement". The OR mask says which of 50 terms feed each
    // of 6 outputs.
    logic [23:0] term_masks [0:49];
    logic [49:0] or_masks   [0:5];
    logic [49:0] terms;

    initial begin
        if (AND_FILE != "") $readmemb(AND_FILE, term_masks);
        else for (int i = 0; i < 50; i++) term_masks[i] = 24'h0;
        if (OR_FILE != "") $readmemb(OR_FILE, or_masks);
        else for (int i = 0; i < 6; i++) or_masks[i] = 50'h0;
    end

    always_comb begin
        for (int t = 0; t < 50; t++) begin
            logic [11:0] inc_mask, cmpl_mask;
            inc_mask  = term_masks[t][11:0];
            cmpl_mask = term_masks[t][23:12];
            terms[t]  = &(~(inc_mask  & ~in) & ~(cmpl_mask &  in));
            // Equivalently: each masked-in input bit must match the required
            // polarity. If no input is selected the term is 1 (default).
            if (inc_mask == 12'h0 && cmpl_mask == 12'h0) terms[t] = 1'b0;
        end
        for (int o = 0; o < 6; o++) out[o] = |(terms & or_masks[o]);
    end
endmodule
