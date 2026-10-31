// SPDX-License-Identifier: MIT
// Logical SN74LS681 model from the TI 1985 TTL Data Book, pages 3-1290/3-1291.
// ASSUMPTION: the TI function tables do not give P/G equations; this model uses
// selected-operand group carry equations documented in spec/chips/ttl_74x681.md.
// Register shifts and serial outputs follow Table 3 literally, including the
// unusual right-shift arithmetic mapping.
`timescale 1ns/1ps
module ttl_74x681 (
    input  logic       clk,
    input  logic       m,
    input  logic [2:0] asel,
    input  logic       cn,
    input  logic [2:0] rs,
    input  logic [3:0] io_in,
    input  logic       li_in,
    input  logic       ri_in,
    output logic [3:0] io_out,
    output logic       io_drive,
    output logic       li_ro_out,
    output logic       li_ro_drive,
    output logic       ri_lo_out,
    output logic       ri_lo_drive,
    output logic [3:0] f,
    output logic       p_bar,
    output logic       g_bar,
    output logic       cn4,
    output logic [3:0] word_a,
    output logic [3:0] word_b
);
    logic [3:0] word_a_q;
    logic [3:0] word_b_q;
    logic       serial_q;
    logic [3:0] logic_base;
    logic [3:0] alu_x;
    logic [3:0] alu_y;
    logic [3:0] bit_propagate;
    logic [3:0] bit_generate;
    logic [3:0] alu_sum;
    logic       group_propagate;
    logic       group_generate;

    always_comb begin
        logic_base = 4'h0;
        alu_x = 4'h0;
        alu_y = 4'h0;

        if (m) begin
            case (asel)
                3'b000: logic_base = 4'h0;
                3'b001: logic_base = word_a_q ^ word_b_q;
                3'b010: logic_base = ~(word_a_q ^ word_b_q);
                3'b011: logic_base = 4'hF;
                3'b100: logic_base = word_a_q & word_b_q;
                3'b101: logic_base = (~word_a_q) | word_b_q;
                3'b110: logic_base = (~word_a_q) & word_b_q;
                3'b111: logic_base = word_a_q | word_b_q;
                default: logic_base = 4'h0;
            endcase
            alu_x = 4'h0;
            alu_y = logic_base;
        end else begin
            case (asel)
                3'b000: begin alu_x = 4'h0;       alu_y = 4'hF;       end
                3'b001: begin alu_x = word_b_q;   alu_y = ~word_a_q;  end
                3'b010: begin alu_x = word_a_q;   alu_y = ~word_b_q;  end
                3'b011: begin alu_x = word_a_q;   alu_y = word_b_q;   end
                3'b100: begin alu_x = 4'h0;       alu_y = word_b_q;   end
                3'b101: begin alu_x = 4'h0;       alu_y = ~word_b_q;  end
                3'b110: begin alu_x = word_a_q;   alu_y = 4'h0;       end
                3'b111: begin alu_x = ~word_a_q;  alu_y = 4'h0;       end
                default: begin alu_x = 4'h0;       alu_y = 4'h0;       end
            endcase
        end

        bit_propagate = alu_x | alu_y;
        bit_generate = alu_x & alu_y;
        alu_sum = alu_x + alu_y + {3'b000, cn};
        group_propagate = &bit_propagate;
        group_generate = bit_generate[3] |
                         (bit_propagate[3] & bit_generate[2]) |
                         (&bit_propagate[3:2] & bit_generate[1]) |
                         (&bit_propagate[3:1] & bit_generate[0]);

        f = alu_sum[3:0];
        cn4 = group_generate | (group_propagate & cn);
        p_bar = ~group_propagate;
        g_bar = ~group_generate;
    end

    always_comb begin
        word_a = word_a_q;
        word_b = word_b_q;
        io_out = f;
        io_drive = 1'b1;
        li_ro_out = serial_q;
        li_ro_drive = 1'b0;
        ri_lo_out = serial_q;
        ri_lo_drive = 1'b0;

        case (rs)
            3'b001, 3'b111: io_drive = 1'b0;
            3'b010, 3'b011: ri_lo_drive = 1'b1;
            3'b100, 3'b101: li_ro_drive = 1'b1;
            default: ;
        endcase
    end

    // TI specifies no reset pin; the register contents are unspecified at power-up.
    always_ff @(posedge clk) begin
        case (rs)
            3'b000: word_b_q <= f;
            3'b001: word_b_q <= io_in;
            3'b010: begin
                word_b_q <= {li_in, word_b_q[3:1]};
                serial_q <= word_b_q[0];
            end
            3'b011: begin
                word_b_q <= {word_b_q[3], li_in, word_b_q[2:1]};
                serial_q <= word_b_q[0];
            end
            3'b100: begin
                word_b_q <= {word_b_q[2:0], ri_in};
                serial_q <= word_b_q[2];
            end
            3'b101: begin
                word_b_q <= {word_b_q[3], word_b_q[1], word_b_q[0], ri_in};
                serial_q <= word_b_q[1];
            end
            3'b110: ;
            3'b111: word_a_q <= io_in;
            default: ;
        endcase
    end
endmodule
