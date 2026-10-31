// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_ttl_74x681;
    logic clk;
    logic m;
    logic [2:0] asel;
    logic cn;
    logic [2:0] rs;
    logic [3:0] io_in;
    logic li_in;
    logic ri_in;
    logic [3:0] io_out;
    logic io_drive;
    logic li_ro_out;
    logic li_ro_drive;
    logic ri_lo_out;
    logic ri_lo_drive;
    logic [3:0] f;
    logic p_bar;
    logic g_bar;
    logic cn4;
    logic [3:0] word_a;
    logic [3:0] word_b;
    int errors;
    int ai;
    int bi;
    int mi;
    int si;
    int ci;
    logic [3:0] ref_x;
    logic [3:0] ref_y;
    logic [3:0] expected;
    logic [4:0] ref_without_cn;
    logic ref_p;
    logic ref_g;
    logic ref_cn4;

    ttl_74x681 dut (
        .clk(clk),
        .m(m),
        .asel(asel),
        .cn(cn),
        .rs(rs),
        .io_in(io_in),
        .li_in(li_in),
        .ri_in(ri_in),
        .io_out(io_out),
        .io_drive(io_drive),
        .li_ro_out(li_ro_out),
        .li_ro_drive(li_ro_drive),
        .ri_lo_out(ri_lo_out),
        .ri_lo_drive(ri_lo_drive),
        .f(f),
        .p_bar(p_bar),
        .g_bar(g_bar),
        .cn4(cn4),
        .word_a(word_a),
        .word_b(word_b)
    );

    function automatic [3:0] expected_result;
        input logic m_i;
        input logic [2:0] sel_i;
        input logic [3:0] a_i;
        input logic [3:0] b_i;
        input logic cn_i;
        logic [3:0] base;
        logic [4:0] extended;
        begin
            base = 4'h0;
            extended = 5'h0;
            if (!m_i) begin
                case (sel_i)
                    3'b000: expected_result = cn_i ? 4'h0 : 4'hF;
                    3'b001: expected_result = cn_i ? (b_i - a_i) : (b_i - a_i - 4'd1);
                    3'b010: expected_result = cn_i ? (a_i - b_i) : (a_i - b_i - 4'd1);
                    3'b011: expected_result = cn_i ? (a_i + b_i + 4'd1) : (a_i + b_i);
                    3'b100: expected_result = cn_i ? (b_i + 4'd1) : b_i;
                    3'b101: expected_result = cn_i ? ((~b_i) + 4'd1) : (~b_i);
                    3'b110: expected_result = cn_i ? (a_i + 4'd1) : a_i;
                    3'b111: expected_result = cn_i ? ((~a_i) + 4'd1) : (~a_i);
                    default: expected_result = 4'h0;
                endcase
            end else begin
                case (sel_i)
                    3'b000: base = 4'h0;
                    3'b001: base = a_i ^ b_i;
                    3'b010: base = ~(a_i ^ b_i);
                    3'b011: base = 4'hF;
                    3'b100: base = a_i & b_i;
                    3'b101: base = (~a_i) | b_i;
                    3'b110: base = (~a_i) & b_i;
                    3'b111: base = a_i | b_i;
                    default: base = 4'h0;
                endcase
                extended = {1'b0, base} + {4'b0000, cn_i};
                expected_result = extended[3:0];
            end
        end
    endfunction

    task automatic selected_operands;
        input logic m_i;
        input logic [2:0] sel_i;
        input logic [3:0] a_i;
        input logic [3:0] b_i;
        output logic [3:0] x_o;
        output logic [3:0] y_o;
        logic [3:0] base;
        begin
            x_o = 4'h0;
            y_o = 4'h0;
            base = 4'h0;
            if (m_i) begin
                case (sel_i)
                    3'b000: base = 4'h0;
                    3'b001: base = a_i ^ b_i;
                    3'b010: base = ~(a_i ^ b_i);
                    3'b011: base = 4'hF;
                    3'b100: base = a_i & b_i;
                    3'b101: base = (~a_i) | b_i;
                    3'b110: base = (~a_i) & b_i;
                    3'b111: base = a_i | b_i;
                    default: base = 4'h0;
                endcase
                x_o = 4'h0;
                y_o = base;
            end else begin
                case (sel_i)
                    3'b000: begin x_o = 4'h0;  y_o = 4'hF;  end
                    3'b001: begin x_o = b_i;    y_o = ~a_i; end
                    3'b010: begin x_o = a_i;    y_o = ~b_i; end
                    3'b011: begin x_o = a_i;    y_o = b_i;  end
                    3'b100: begin x_o = 4'h0;  y_o = b_i;  end
                    3'b101: begin x_o = 4'h0;  y_o = ~b_i; end
                    3'b110: begin x_o = a_i;    y_o = 4'h0;  end
                    3'b111: begin x_o = ~a_i;   y_o = 4'h0;  end
                    default: begin x_o = 4'h0;  y_o = 4'h0;  end
                endcase
            end
        end
    endtask

    task automatic tick;
        begin
            clk = 1'b0;
            #1;
            clk = 1'b1;
            #1;
            clk = 1'b0;
            #1;
        end
    endtask

    initial begin
        errors = 0;
        clk = 1'b0;
        m = 1'b0;
        asel = 3'b000;
        cn = 1'b0;
        rs = 3'b111;
        io_in = 4'h0;
        li_in = 1'b0;
        ri_in = 1'b0;

        // Exhaust all A/B values, modes, selections, and carry inputs.
        for (ai = 0; ai < 16; ai = ai + 1) begin
            for (bi = 0; bi < 16; bi = bi + 1) begin
                rs = 3'b111;
                io_in = ai[3:0];
                tick();
                rs = 3'b001;
                io_in = bi[3:0];
                tick();
                rs = 3'b110;
                if (word_a !== ai[3:0] || word_b !== bi[3:0]) begin
                    errors = errors + 1;
                    if (errors < 10) $display("load mismatch: A=%0h B=%0h got A=%0h B=%0h", ai[3:0], bi[3:0], word_a, word_b);
                end
                for (mi = 0; mi < 2; mi = mi + 1) begin
                    m = mi[0];
                    for (si = 0; si < 8; si = si + 1) begin
                        asel = si[2:0];
                        for (ci = 0; ci < 2; ci = ci + 1) begin
                            cn = ci[0];
                            #1;
                            expected = expected_result(m, asel, word_a, word_b, cn);
                            selected_operands(m, asel, word_a, word_b, ref_x, ref_y);
                            ref_without_cn = {1'b0, ref_x} + {1'b0, ref_y};
                            ref_p = &(ref_x | ref_y);
                            ref_g = ref_without_cn[4];
                            ref_cn4 = ref_g | (ref_p & cn);
                            if (f !== expected || cn4 !== ref_cn4 || p_bar !== ~ref_p || g_bar !== ~ref_g) begin
                                errors = errors + 1;
                                if (errors < 10) begin
                                    $display("ALU mismatch: A=%0h B=%0h M=%0b AS=%0b Cn=%0b F=%0h expected=%0h Pbar=%0b Gbar=%0b Cn4=%0b", word_a, word_b, m, asel, cn, f, expected, p_bar, g_bar, cn4);
                                end
                            end
                            if (io_drive !== 1'b1 || io_out !== f) begin
                                errors = errors + 1;
                                if (errors < 10) $display("hold-mode bus mismatch: drive=%0b out=%0h F=%0h", io_drive, io_out, f);
                            end
                        end
                    end
                end
            end
        end

        // Table 3 state and bidirectional-port modes.
        m = 1'b0;
        asel = 3'b010;
        cn = 1'b1;
        rs = 3'b111;
        io_in = 4'hA;
        tick();
        rs = 3'b001;
        io_in = 4'h6;
        tick();
        if (word_a !== 4'hA || word_b !== 4'h6) errors = errors + 1;

        rs = 3'b000;
        #1;
        if (io_drive !== 1'b1 || io_out !== f || li_ro_drive !== 1'b0 || ri_lo_drive !== 1'b0) errors = errors + 1;
        tick();
        if (word_a !== 4'hA || word_b !== 4'h4) errors = errors + 1; // A-B with carry.

        rs = 3'b001;
        io_in = 4'h5;
        #1;
        if (io_drive !== 1'b0 || li_ro_drive !== 1'b0 || ri_lo_drive !== 1'b0) errors = errors + 1;
        tick();
        if (word_a !== 4'hA || word_b !== 4'h5) errors = errors + 1;

        rs = 3'b010;
        li_in = 1'b1;
        #1;
        if (io_drive !== 1'b1 || li_ro_drive !== 1'b0 || ri_lo_drive !== 1'b1) errors = errors + 1;
        tick();
        if (word_a !== 4'hA || word_b !== 4'hA || ri_lo_out !== 1'b1) errors = errors + 1;

        rs = 3'b011;
        li_in = 1'b0;
        tick();
        if (word_a !== 4'hA || word_b !== 4'h9 || ri_lo_out !== 1'b0) errors = errors + 1;

        rs = 3'b100;
        ri_in = 1'b1;
        #1;
        if (io_drive !== 1'b1 || li_ro_drive !== 1'b1 || ri_lo_drive !== 1'b0) errors = errors + 1;
        tick();
        if (word_a !== 4'hA || word_b !== 4'h3 || li_ro_out !== 1'b0) errors = errors + 1;

        rs = 3'b101;
        ri_in = 1'b0;
        tick();
        if (word_a !== 4'hA || word_b !== 4'h6 || li_ro_out !== 1'b1) errors = errors + 1;

        rs = 3'b110;
        tick();
        if (word_a !== 4'hA || word_b !== 4'h6 || io_drive !== 1'b1 || li_ro_drive !== 1'b0 || ri_lo_drive !== 1'b0) errors = errors + 1;

        rs = 3'b111;
        io_in = 4'h3;
        #1;
        if (io_drive !== 1'b0 || li_ro_drive !== 1'b0 || ri_lo_drive !== 1'b0) errors = errors + 1;
        tick();
        if (word_a !== 4'h3 || word_b !== 4'h6) errors = errors + 1;

        if (errors != 0) $fatal(1, "tb_ttl_74x681: %0d errors", errors);
        $display("PASS: tb_ttl_74x681");
        $finish;
    end
endmodule
