// ASSUMPTION: ideal digital levels; normalized function interface; see spec/chips/ttl_74x657.md.
// ttl_74x657 - octal bus transceiver with 8-bit parity generator/checker, 3-state outputs.
//
// Combines a non-inverting '245-style transceiver with a '280-style parity engine.
// Direction is controlled by t_r (1 = transmit A->B, 0 = receive B->A).
// oe_n disables all 3-state outputs (A, B, PARITY, /ERR).
// `odd` selects parity polarity: 1 = odd parity, 0 = even parity. The datasheet
// pin is labeled "ODD/EVEN" (overbar on EVEN) which maps to active-high odd.
//
// In transmit mode the chip drives PARITY with the value that makes the total
// (a_in + parity_out) match the selected polarity, and /ERR is Hi-Z.
// In receive mode the chip uses parity_in to compute /ERR: low means the
// supplied parity does not match the selected polarity over b_in.
module ttl_74x657 (
    input  logic       t_r,
    input  logic       oe_n,
    input  logic       odd,
    input  logic [7:0] a_in,
    input  logic [7:0] b_in,
    input  logic       parity_in,
    output logic [7:0] a_out,
    output logic [7:0] b_out,
    output logic       parity_out,
    output logic       err_n,
    output logic       a_oe_n,
    output logic       b_oe_n,
    output logic       parity_oe_n,
    output logic       err_oe_n
);
    // Parity generated for the A-side data: result makes a_in + parity_out match
    // the selected polarity.
    //   odd=1, parity_out = ~^a_in  ->  popcount(a_in)+parity_out is odd
    //   odd=0, parity_out =  ^a_in  ->  popcount(a_in)+parity_out is even
    // i.e., parity_out = (^a_in) XOR odd.
    assign parity_out = (^a_in) ^ odd;

    // /ERR (active low, no-error indicator) over the B-side data plus parity_in:
    //   /ERR = NOT( (^b_in) XOR parity_in XOR odd )
    // /ERR=1 means the supplied parity matches the selected polarity.
    assign err_n = ~((^b_in) ^ parity_in ^ odd);

    always_comb begin
        a_out  = 8'h00; b_out  = 8'h00;
        a_oe_n = 1'b1;  b_oe_n = 1'b1;
        parity_oe_n = 1'b1;
        err_oe_n    = 1'b1;
        if (!oe_n) begin
            if (t_r) begin
                // Transmit (A->B): A is input, B drives a_in. PARITY drives, /ERR is Hi-Z.
                b_out       = a_in;
                b_oe_n      = 1'b0;
                parity_oe_n = 1'b0;
            end else begin
                // Receive (B->A): B is input, A drives b_in. /ERR drives, PARITY is input.
                a_out    = b_in;
                a_oe_n   = 1'b0;
                err_oe_n = 1'b0;
            end
        end
    end
endmodule
