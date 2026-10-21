// ASSUMPTION: Z is represented by per-section flags; timing is not modeled.
module ttl_74x16952 (
    input  logic [15:0] a_in,
    input  logic [15:0] b_in,
    input  logic [1:0] clkenab_n,
    input  logic [1:0] clkab,
    input  logic [1:0] oeab_n,
    input  logic [1:0] clkenba_n,
    input  logic [1:0] clkba,
    input  logic [1:0] oeba_n,
    output logic [15:0] a_out,
    output logic [15:0] b_out,
    output logic [1:0] a_drive,
    output logic [1:0] b_drive
);
    logic [15:0] a_to_b_reg;
    logic [15:0] b_to_a_reg;

    for (genvar section = 0; section < 2; section++) begin : g_section
        localparam integer BASE = section * 8;
        always_ff @(posedge clkab[section]) begin
            if (!clkenab_n[section])
                a_to_b_reg[BASE +: 8] <= a_in[BASE +: 8];
        end
        always_ff @(posedge clkba[section]) begin
            if (!clkenba_n[section])
                b_to_a_reg[BASE +: 8] <= b_in[BASE +: 8];
        end
        always_comb begin
            b_drive[section] = !oeab_n[section];
            a_drive[section] = !oeba_n[section];
            b_out[BASE +: 8] = b_drive[section] ? a_to_b_reg[BASE +: 8] : 8'h00;
            a_out[BASE +: 8] = a_drive[section] ? b_to_a_reg[BASE +: 8] : 8'h00;
        end
    end
endmodule
