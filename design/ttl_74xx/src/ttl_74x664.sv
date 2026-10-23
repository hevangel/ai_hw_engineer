// ASSUMPTION: ideal digital levels and settled controls; see spec/chips/ttl_74x664.md.
// TI SN74HC664: G_N enables one direction selected by DIR; data is inverted.
module ttl_74x664 (
    input  logic       g_n,
    input  logic       dir,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    input  logic       api,
    input  logic       bpi,
    output logic [7:0] a_out,
    output logic [7:0] b_out,
    output logic       a_drive,
    output logic       b_drive,
    output logic       apo,
    output logic       bpo,
    output logic       apo_drive,
    output logic       bpo_drive
);
    logic a_even_parity;
    logic b_even_parity;

    assign a_even_parity = ~^{a_in, api};
    assign b_even_parity = ~^{b_in, bpi};

    always_comb begin
        a_drive = ~g_n && ~dir;
        b_drive = ~g_n && dir;
        apo_drive = b_drive;
        bpo_drive = a_drive;
        a_out = a_drive ? ~b_in : 8'h00;
        b_out = b_drive ? ~a_in : 8'h00;
        apo = apo_drive ? a_even_parity : 1'b0;
        bpo = bpo_drive ? b_even_parity : 1'b0;
    end
endmodule
