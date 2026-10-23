// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_ttl_74x732;
    logic s0, s1, s2;
    logic oe_a_n, oe_b_n, oe_c_n;
    logic [3:0] a, b, c;
    logic [3:0] a_out, b_out, c_out;
    logic a_drive, b_drive, c_drive;

    ttl_74x732 dut (.*);

    task automatic exercise(
        input int unsigned selection,
        input logic [2:0] enables_n,
        input logic [3:0] av,
        input logic [3:0] bv,
        input logic [3:0] cv
    );
        logic [3:0] exp_a, exp_b, exp_c;
        logic exp_a_drive, exp_b_drive, exp_c_drive;
        begin
            s0 = selection[2];
            s1 = selection[1];
            s2 = selection[0];
            oe_a_n = enables_n[2];
            oe_b_n = enables_n[1];
            oe_c_n = enables_n[0];
            a = av;
            b = bv;
            c = cv;

            exp_a = 4'b0000;
            exp_b = 4'b0000;
            exp_c = 4'b0000;
            exp_a_drive = 1'b0;
            exp_b_drive = 1'b0;
            exp_c_drive = 1'b0;

            // Independent table transcription, with select bit order S0,S1,S2.
            case (selection[2:0])
                3'b000: if (!oe_c_n) begin exp_c = ~av; exp_c_drive = 1'b1; end
                3'b100: if (!oe_a_n) begin exp_a = ~cv; exp_a_drive = 1'b1; end
                3'b001: if (!oe_c_n) begin exp_c = ~bv; exp_c_drive = 1'b1; end
                3'b101: if (!oe_b_n) begin exp_b = ~cv; exp_b_drive = 1'b1; end
                3'b010: if (!oe_b_n) begin exp_b = ~av; exp_b_drive = 1'b1; end
                3'b110: if (!oe_a_n) begin exp_a = ~bv; exp_a_drive = 1'b1; end
                3'b011, 3'b111: begin
                    if (!oe_b_n) begin exp_b = ~av; exp_b_drive = 1'b1; end
                    if (!oe_c_n) begin exp_c = ~av; exp_c_drive = 1'b1; end
                end
                default: begin end
            endcase

            #1;
            if ({a_drive, b_drive, c_drive} !==
                {exp_a_drive, exp_b_drive, exp_c_drive} ||
                a_out !== exp_a || b_out !== exp_b || c_out !== exp_c) begin
                $fatal(1,
                    "selection=%03b oe_n=%03b actual drive=%03b data=%h/%h/%h expected drive=%03b data=%h/%h/%h",
                    selection[2:0], enables_n,
                    {a_drive, b_drive, c_drive}, a_out, b_out, c_out,
                    {exp_a_drive, exp_b_drive, exp_c_drive}, exp_a, exp_b, exp_c);
            end
        end
    endtask

    int unsigned selection;
    int unsigned enables;
    int unsigned pattern;
    initial begin
        for (selection = 0; selection < 8; selection++) begin
            for (enables = 0; enables < 8; enables++) begin
                for (pattern = 0; pattern < 16; pattern++) begin
                    exercise(selection, enables[2:0], pattern[3:0],
                            pattern[3:0] ^ 4'hA, ~pattern[3:0]);
                end
            end
        end
        $display("PASS: tb_ttl_74x732");
        $finish;
    end
endmodule
