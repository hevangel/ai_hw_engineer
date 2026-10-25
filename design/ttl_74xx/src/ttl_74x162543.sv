// ASSUMPTION: Each physical output's Z state uses a per-section drive flag.
module ttl_74x162543 (
    input  logic [15:0] a_in,
    input  logic [15:0] b_in,
    input  logic [1:0] ceab_n,
    input  logic [1:0] leab_n,
    input  logic [1:0] oeab_n,
    input  logic [1:0] ceba_n,
    input  logic [1:0] leba_n,
    input  logic [1:0] oeba_n,
    output logic [15:0] a_out,
    output logic [15:0] b_out,
    output logic [1:0] a_drive,
    output logic [1:0] b_drive
);
    logic [15:0] a_to_b_latch;
    logic [15:0] b_to_a_latch;

    for (genvar section = 0; section < 2; section++) begin : g_section
        localparam integer BASE = section * 8;
        always_latch begin
            if (!ceab_n[section] && !leab_n[section])
                a_to_b_latch[BASE +: 8] = a_in[BASE +: 8];
            if (!ceba_n[section] && !leba_n[section])
                b_to_a_latch[BASE +: 8] = b_in[BASE +: 8];
        end
        always_comb begin
            b_drive[section] = !ceab_n[section] && !oeab_n[section];
            a_drive[section] = !ceba_n[section] && !oeba_n[section];
            b_out[BASE +: 8] = b_drive[section] ? a_to_b_latch[BASE +: 8] : 8'h00;
            a_out[BASE +: 8] = a_drive[section] ? b_to_a_latch[BASE +: 8] : 8'h00;
        end
    end
endmodule
