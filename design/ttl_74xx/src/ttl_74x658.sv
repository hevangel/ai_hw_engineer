// ASSUMPTION: ideal digital levels and settled controls; see spec/chips/ttl_74x658.md.
// TI SN74HC658: both transfer directions invert data; GBA_N and GAB enable independently.
module ttl_74x658 (
    input  logic       gba_n,
    input  logic       gab,
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
        a_drive = ~gba_n;
        b_drive = gab;
        apo_drive = gab;
        bpo_drive = ~gba_n;
        a_out = a_drive ? ~b_in : 8'h00;
        b_out = b_drive ? ~a_in : 8'h00;
        apo = apo_drive ? a_even_parity : 1'b0;
        bpo = bpo_drive ? b_even_parity : 1'b0;
    end
endmodule
