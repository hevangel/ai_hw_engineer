// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x412.md.
// ttl_74x412 - Multi-mode buffered 8-bit latches (Intel 3212/8212 equivalent).
// Operates as a latch with output enable and strobe.
module ttl_74x412 (
    input  logic       md,         // mode: 0=hold, 1=transparent
    input  logic       stb,        // strobe (active high captures)
    input  logic       ds1, ds2_n, // device-select pair: enable when ds1=1, ds2_n=0
    input  logic [7:0] d,
    output logic [7:0] q,
    output logic       int_n
);
    logic [7:0] latch_q;
    logic       enable;
    assign enable = ds1 & ~ds2_n;
    always_latch begin
        if (md || stb) latch_q = d;
    end
    assign q = enable ? latch_q : 8'h00;
    assign int_n = ~stb;
endmodule
