// ASSUMPTION: PRODUCT PREVIEW source (SCES356B). Native setup/hold windows,
// the FSTA flexible-setup-time analog delay, ERC and the VREF/BIAS VCC
// references are omitted. Register contents power up unspecified. SSCLK is a
// bidirectional open-drain GTLP clock pin: this model exposes the resolved
// bus observation (ssclk) plus a low-only sink mask (ssclk_sink) for the
// phases where the device forwards SYSCLK onto that bus.
module ttl_74x1627 (
    input  logic [17:0] a_in,
    input  logic [17:0] b_in,
    input  logic        oe_n,
    input  logic        dir,
    input  logic        cms,
    input  logic        ckoen_n,
    input  logic        sysclk,
    input  logic        ssclk,
    output logic [17:0] a_out,
    output logic [17:0] a_drive,
    output logic [17:0] b_drive,
    output logic        clkout,
    output logic        clkout_drive,
    output logic        ssclk_sink
);
    logic [17:0] state_ab;
    logic [17:0] state_ba;
    logic        clocks_enabled;
    logic        ba_clk;

    assign clocks_enabled = !ckoen_n;
    assign ba_clk = cms ? sysclk : ssclk;

    always_ff @(posedge sysclk)
        if (clocks_enabled)
            state_ab <= a_in;

    always_ff @(posedge ba_clk)
        if (clocks_enabled)
            state_ba <= b_in;

    always_comb begin
        a_drive = '0;
        a_out = '0;
        b_drive = '0;
        clkout = 1'b0;
        clkout_drive = 1'b0;
        ssclk_sink = 1'b0;
        if (!oe_n && !dir)
            b_drive = ~(ckoen_n ? a_in : state_ab);
        if (!oe_n && dir) begin
            a_drive = '1;
            a_out = ckoen_n ? b_in : state_ba;
        end
        if (clocks_enabled) begin
            clkout_drive = 1'b1;
            clkout = (dir == 1'b0 || cms) ? sysclk : ssclk;
            if (!dir || cms)
                ssclk_sink = sysclk;
        end
    end
endmodule
