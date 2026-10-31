// ASSUMPTION: see spec/chips/ttl_74x2032.md. The source's STORAGE MODE and
// SELECT FUNCTION tables reference LCA/LCB/SEL1/SEL0 pins that do not exist
// on the 'FB2032; only the physically pinned controls are modeled here.
// Externally resolved powered logic; latch power-up contents unspecified;
// JTAG/bias/electrical behavior omitted (PRODUCT PREVIEW part).
//
// ttl_74x2032 - 9-bit TTL/BTL competition transceiver.
// Bit 8 of each port is the bus parity bit (AP/BP); bits 7:0 are A8..A1 /
// B8..B1, bit 7 being the most significant arbitration bit. A-port data is
// latched by LE (high = latched, low = transparent). The B port is
// open-collector, enabled by oeb && !oeb_n, carrying inverted ("A-bar")
// data. With compete low, the arbitration chain computes, per data bit k,
// survival = latched A bit is 1 or the observed B line is released; win is
// high when all eight data bits survive, and a data-bit driver is gated by
// the survival of all more significant bits so a losing module releases the
// lines below its loss point. BP is driven like a data bit from latched AP
// without chain gating. win is forced low while compete is high.
module ttl_74x2032 (
    input  logic       oea,
    input  logic       oeb,
    input  logic       oeb_n,
    input  logic       le,
    input  logic       compete,
    input  logic [8:0] a_in,
    input  logic [8:0] b_in,
    output logic       win,
    output logic [8:0] a_out,
    output logic       a_drive,
    output logic [8:0] b_out,    // always zero; open-collector state is b_drive
    output logic [8:0] b_drive   // per-pin sink flags: 1 = sinking line low
);
    logic [8:0] a_lat;
    logic [7:0] pass;            // survival of arbitration bits B8..B1
    logic       b_en;
    logic       competing;

    always_latch begin
        if (!le) a_lat = a_in;
    end

    always_comb begin
        competing = !compete;
        b_en      = oeb && !oeb_n;
        for (int k = 0; k < 8; k++)
            pass[k] = a_lat[k] || b_in[k];
    end

    always_comb begin
        win = competing;
        for (int k = 0; k < 8; k++)
            win = win && pass[k];
    end

    always_comb begin
        a_drive = oea;
        a_out   = '0;
        b_out   = '0;
        b_drive = '0;
        if (oea)
            a_out = ~b_in;
        if (b_en) begin
            b_drive[8] = a_lat[8];
            for (int k = 0; k < 8; k++) begin
                b_drive[k] = a_lat[k];
                if (competing) begin
                    for (int h = k + 1; h < 8; h++)
                        b_drive[k] = b_drive[k] && pass[h];
                end
            end
        end
    end
endmodule
