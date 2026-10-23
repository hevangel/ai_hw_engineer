// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x1760.md.
// ttl_74x1760 - 10-bit 4-way latched address multiplexer.
// Selects one of four 10-bit address sources, latches it (transparent when
// le=1), and presents on the output with optional 3-state via oe_n.
module ttl_74x1760 (
    input  logic        oe_n,
    input  logic        le,           // transparent latch enable: 1 = pass, 0 = hold
    input  logic [1:0]  sel,
    input  logic [9:0]  a, b, c, d,
    output logic [9:0]  y,
    output logic        hiz
);
    logic [9:0] mux_out;
    logic [9:0] q;

    always_comb begin
        case (sel)
            2'b00: mux_out = a;
            2'b01: mux_out = b;
            2'b10: mux_out = c;
            2'b11: mux_out = d;
        endcase
    end

    always_latch if (le) q = mux_out;

    assign y   = oe_n ? 10'b0 : q;
    assign hiz = oe_n;
endmodule
