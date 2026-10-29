// ASSUMPTION: see spec/chips/ttl_74x2040.md. Externally resolved powered
// logic; released B lines read high only through the board's bias network;
// JTAG/bias/electrical behavior omitted (PRODUCT PREVIEW part).
//
// ttl_74x2040 - 8-bit TTL/BTL transceiver with split TTL I/O.
// A-input pins AI1..AI8 drive the open-collector B port ("A-bar data": an AI
// pin high sinks its B line) while oeb=1 and oeb_n=0. The three-state
// A-output pins AO1..AO8 carry "B-bar data" (~b_in) while oea=1. The two
// directions are independent and purely combinational.
module ttl_74x2040 (
    input  logic       oea,
    input  logic       oeb,
    input  logic       oeb_n,
    input  logic [7:0] ai_in,    // AI1..AI8 TTL levels
    input  logic [7:0] b_in,     // B1..B8 resolved BTL levels
    output logic [7:0] ao_out,
    output logic       ao_drive,
    output logic [7:0] b_out,    // always zero; open-collector state is b_drive
    output logic [7:0] b_drive   // per-pin sink flags: 1 = sinking line low
);
    always_comb begin
        ao_drive = oea;
        ao_out   = '0;
        b_out    = '0;
        b_drive  = '0;
        if (oea)
            ao_out = ~b_in;
        if (oeb && !oeb_n)
            b_drive = ai_in;     // AI bit high sinks its B line
    end
endmodule
