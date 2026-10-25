// ASSUMPTION: native setup/hold windows are not modeled; register contents
// power up unspecified. The B port is open-drain GTL/GTL+: b_drive masks
// indicate which pins are actively sunk low. CE is a common active-low
// qualified storage enable; output enables are per bank and do not gate
// storage.
module ttl_74x16923 (
    input  logic [17:0] a_in,
    input  logic [17:0] b_in,
    input  logic [1:0]  oeab_n,
    input  logic [1:0]  oeba_n,
    input  logic        ceab_n,
    input  logic        ceba_n,
    input  logic        clkab,
    input  logic        clkba,
    output logic [17:0] a_out,
    output logic [1:0]  a_drive,
    output logic [17:0] b_drive
);
    logic [17:0] state_ab;
    logic [17:0] state_ba;

    for (genvar bank = 0; bank < 2; bank++) begin : g_bank
        localparam integer BASE = bank * 9;
        always_ff @(posedge clkab)
            if (!ceab_n)
                state_ab[BASE +: 9] <= a_in[BASE +: 9];
        always_ff @(posedge clkba)
            if (!ceba_n)
                state_ba[BASE +: 9] <= b_in[BASE +: 9];
    end

    always_comb begin
        a_out = '0;
        a_drive = '0;
        b_drive = '0;
        for (int bank = 0; bank < 2; bank++) begin
            if (!oeba_n[bank]) begin
                a_drive[bank] = 1'b1;
                a_out[bank*9 +: 9] = state_ba[bank*9 +: 9];
            end
            if (!oeab_n[bank])
                b_drive[bank*9 +: 9] = ~state_ab[bank*9 +: 9];
        end
    end
endmodule
