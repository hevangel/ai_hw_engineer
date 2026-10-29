// ASSUMPTION: qualified feedback after a settled directional transfer;
// no external drivers in feedback mode. See the per-part specification.
module ttl_74x1623 (
    input logic g_ba_n, g_ab,
    input logic [7:0] a_in, b_in,
    output logic [7:0] a_out, b_out,
    output logic a_drive, b_drive
);
    logic [7:0] held_a, held_b;
    always_latch begin
        if (!g_ba_n && !g_ab) begin
            held_b=b_in; held_a=b_in;
        end else if (g_ba_n && g_ab) begin
            held_a=a_in; held_b=a_in;
        end
    end
    always_comb begin
        a_drive=!g_ba_n;
        b_drive=g_ab;
        a_out=8'b0;
        b_out=8'b0;
        case ({g_ba_n,g_ab})
            2'b00: a_out=b_in;
            2'b11: b_out=a_in;
            2'b01: begin a_out=held_a; b_out=held_b; end
            default: begin end
        endcase
    end
endmodule
