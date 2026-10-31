// ASSUMPTION: native setup/hold windows are not modeled; register contents
// power up unspecified. The B port is open-drain GTL/GTL+: b_drive masks
// indicate which pins are actively sunk low. CE high holds storage but does
// not itself disable outputs; outputs obey the active-low output enables.
module ttl_74x16622 (
    input  logic [17:0] a_in,
    input  logic [17:0] b_in,
    input  logic        oeab_n,
    input  logic        oeba_n,
    input  logic        clkab,
    input  logic        clkba,
    input  logic [1:0]  ceab,
    input  logic [1:0]  ceba,
    output logic [17:0] a_out,
    output logic [17:0] a_drive,
    output logic [17:0] b_drive
);
    logic [17:0] state_ab;
    logic [17:0] state_ba;

    for (genvar bank = 0; bank < 2; bank++) begin : g_bank
        localparam integer BASE = bank * 9;
        always_ff @(posedge clkab)
            if (!ceab[bank])
                state_ab[BASE +: 9] <= a_in[BASE +: 9];
        always_ff @(posedge clkba)
            if (!ceba[bank])
                state_ba[BASE +: 9] <= b_in[BASE +: 9];
    end

    always_comb begin
        a_drive = '0;
        a_out = '0;
        b_drive = '0;
        if (!oeba_n) begin
            a_drive = '1;
            a_out = state_ba;
        end
        if (!oeab_n)
            b_drive = ~state_ab;
    end
endmodule
