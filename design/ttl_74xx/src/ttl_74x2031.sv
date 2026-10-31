// ASSUMPTION: see spec/chips/ttl_74x2031.md. Externally resolved powered logic;
// storage elements stay live regardless of the SEL mux; power-up contents
// unspecified; JTAG/bias/electrical behavior omitted (PRODUCT PREVIEW part).
//
// ttl_74x2031 - 9-bit TTL/BTL address/data transceiver.
// A port: TTL three-state, enabled by oea. B port: open-collector, enabled by
// oeb && !oeb_n, sinking a line while the selected A-side value is 1 ("A-bar
// data to B bus"). Both directions invert ("B-bar data to A bus").
// SEL1/SEL0 select latch/thru/flip-flop per direction; lca/lcb are latch
// enables (low = transparent) or positive-edge clocks depending on selection.
module ttl_74x2031 (
    input  logic       oea,
    input  logic       oeb,
    input  logic       oeb_n,
    input  logic [8:0] a_in,     // A1..A9 TTL levels
    input  logic [8:0] b_in,     // B1..B9 resolved BTL levels
    input  logic       lca,
    input  logic       lcb,
    input  logic       sel1,
    input  logic       sel0,
    output logic [8:0] a_out,
    output logic       a_drive,
    output logic [8:0] b_out,    // always zero; open-collector state is b_drive
    output logic [8:0] b_drive   // per-pin sink flags: 1 = sinking line low
);
    logic [8:0] latch_ab;        // A->B storage, A-domain data
    logic [8:0] ff_ab;
    logic [8:0] latch_ba;        // B->A storage, TTL-domain (~B) data
    logic [8:0] ff_ba;
    logic [8:0] mux_ab;
    logic [8:0] mux_ba;

    always_latch begin
        if (!lca) latch_ab = a_in;
    end

    always_ff @(posedge lca) begin
        ff_ab <= a_in;
    end

    always_latch begin
        if (!lcb) latch_ba = ~b_in;
    end

    always_ff @(posedge lcb) begin
        ff_ba <= ~b_in;
    end

    always_comb begin
        case ({sel1, sel0})
            2'b00: begin
                mux_ab = latch_ab;
                mux_ba = latch_ba;
            end
            2'b01: begin
                mux_ab = a_in;
                mux_ba = ~b_in;
            end
            2'b10: begin
                mux_ab = ff_ab;
                mux_ba = ff_ba;
            end
            default: begin  // 2'b11: A->B flip-flop, B->A latch
                mux_ab = ff_ab;
                mux_ba = latch_ba;
            end
        endcase
    end

    always_comb begin
        a_drive = oea;
        a_out   = '0;
        b_out   = '0;
        b_drive = '0;
        if (oea)
            a_out = mux_ba;
        if (oeb && !oeb_n)
            b_drive = mux_ab;   // A bit high sinks its B line
    end
endmodule
