// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x2853.md.
// ttl_74x2853 - 8-bit bus transceiver with parity error latch.
// Same data/parity behavior as 74x833 but the error indicator is a
// transparent latch (asynchronous) rather than an edge-triggered FF.
// When le_err = 1 the latch tracks the current point_p; when le_err = 0
// it holds the last sampled value. clr_n asynchronously sets err_n high.
module ttl_74x2853 (
    input  logic       le_err,
    input  logic       clr_n,
    input  logic       oea_n,
    input  logic       oeb_n,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    input  logic       parity_in,
    output logic [7:0] a_out,
    output logic [7:0] b_out,
    output logic       parity_out,
    output logic       err_n,
    output logic       a_oe_n,
    output logic       b_oe_n,
    output logic       parity_oe_n
);
    logic parity_a, point_p;
    logic err_q;

    assign parity_a = ^a_in;
    assign point_p  = ^{b_in, parity_in};

    always_comb begin
        a_out = 8'h00; b_out = 8'h00; parity_out = 1'b0;
        a_oe_n = 1'b1; b_oe_n = 1'b1; parity_oe_n = 1'b1;
        case ({oea_n, oeb_n})
            2'b10: begin
                b_out       = a_in;
                parity_out  = ~parity_a;
                b_oe_n      = 1'b0;
                parity_oe_n = 1'b0;
            end
            2'b01: begin
                a_out  = b_in;
                a_oe_n = 1'b0;
            end
            2'b00: begin
                b_out       = a_in;
                parity_out  = parity_a;
                b_oe_n      = 1'b0;
                parity_oe_n = 1'b0;
            end
            default: ;
        endcase
    end

    always_latch begin
        if (!clr_n)       err_q = 1'b1;
        else if (le_err && !point_p) err_q = 1'b0;
    end

    assign err_n = err_q;
endmodule
