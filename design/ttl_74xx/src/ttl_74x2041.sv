// ASSUMPTION: see spec/chips/ttl_74x2041.md. Externally resolved powered
// logic; pin 25 is modeled as active-low 2OEB_n per the logic-symbol polarity
// indicator; JTAG/bias/electrical behavior omitted (PRODUCT PREVIEW part).
//
// ttl_74x2041 - 7-bit TTL/BTL transceiver with split TTL I/O, partitioned as
// one 1-bit section and two 3-bit sections. oeb (pin 46) is the shared
// active-high B enable routed to every section; oeb_n holds the per-section
// active-low B enables (1OEB_n, 2OEB_n, 3OEB_n) and oea the per-section
// active-high A-output enables (1OEA, 2OEA, 3OEA).
// Bit order: bit 0 = section 1 (1x1), bits 3:1 = section 2 (2x1..2x3),
// bits 6:4 = section 3 (3x1..3x3). AI bits sink their B lines ("A-bar data"
// to the B bus); AO outputs carry ~b_in ("B-bar data" to the AO bus).
module ttl_74x2041 (
    input  logic       oeb,
    input  logic [2:0] oeb_n,
    input  logic [2:0] oea,
    input  logic [6:0] ai_in,
    input  logic [6:0] b_in,
    output logic [6:0] ao_out,
    output logic [2:0] ao_drive,
    output logic [6:0] b_out,    // always zero; open-collector state is b_drive
    output logic [6:0] b_drive   // per-pin sink flags: 1 = sinking line low
);
    always_comb begin
        ao_out   = '0;
        ao_drive = oea;
        b_out    = '0;
        b_drive  = '0;
        if (oea[0])
            ao_out[0] = ~b_in[0];
        for (int i = 1; i <= 3; i++) begin
            if (oea[1])
                ao_out[i] = ~b_in[i];
        end
        for (int i = 4; i <= 6; i++) begin
            if (oea[2])
                ao_out[i] = ~b_in[i];
        end
        if (oeb && !oeb_n[0])
            b_drive[0] = ai_in[0];
        if (oeb && !oeb_n[1]) begin
            for (int i = 1; i <= 3; i++)
                b_drive[i] = ai_in[i];
        end
        if (oeb && !oeb_n[2]) begin
            for (int i = 4; i <= 6; i++)
                b_drive[i] = ai_in[i];
        end
    end
endmodule
