// SPDX-License-Identifier: MIT
// SN74AS759: four non-inverting open-collector bus transceivers.
// Modes are transcribed from TI 1984 TTL Data Book Vol. 3, p. 2-495.
module ttl_74x759 (
    input  logic       g_ab_n,
    input  logic       g_ba,
    input  logic [3:0] a_in,
    input  logic [3:0] b_in,
    output logic [3:0] a_out,
    output logic [3:0] b_out,
    output logic       a_drive,
    output logic       b_drive
);
    logic [3:0] held_a;
    logic [3:0] held_b;

    // ASSUMPTION: model the feedback latch as capturing the selected input
    // while a directional mode is active, then retain that pair in latch mode.
    // The manufacturer preview does not specify the latch transition timing. Use feedback only after a settled directional transfer and with no external bus contention.
    always_latch begin
        if (!g_ab_n && !g_ba) begin
            held_a = a_in;
            held_b = a_in;
        end else if (g_ab_n && g_ba) begin
            held_b = b_in;
            held_a = b_in;
        end
    end

    always_comb begin
        a_out = 4'b0000;
        b_out = 4'b0000;
        a_drive = 1'b0;
        b_drive = 1'b0;

        case ({g_ab_n, g_ba})
            2'b00: begin // A to B, non-inverting
                b_out = a_in;
                b_drive = 1'b1;
            end
            2'b11: begin // B to A, non-inverting
                a_out = b_in;
                a_drive = 1'b1;
            end
            2'b01: begin // Feedback latch: A = B
                a_out = held_a;
                b_out = held_b;
                a_drive = 1'b1;
                b_drive = 1'b1;
            end
            default: begin // 2'b10 isolates both buses
            end
        endcase
    end
endmodule
