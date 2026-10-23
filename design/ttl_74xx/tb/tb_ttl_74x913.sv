module tb_ttl_74x913;
    localparam int CPD = 4;  // CYCLES_PER_DIGIT default
    logic osc, ce_n, we_n;
    logic [3:0] d;
    logic [2:0] k;
    logic [5:0] digit;
    logic [6:0] seg;

    ttl_74x913 dut(.*);

    // Expected BCD font, {g,f,e,d,c,b,a}, per the MM74C912 character font
    // table (the 1977 913 source states identity with the 912).
    function automatic logic [6:0] exp_font(input logic [3:0] code);
        case (code)
            4'd0:    exp_font = 7'b0111111;
            4'd1:    exp_font = 7'b0000110;
            4'd2:    exp_font = 7'b1011011;
            4'd3:    exp_font = 7'b1001111;
            4'd4:    exp_font = 7'b1100110;
            4'd5:    exp_font = 7'b1101101;
            4'd6:    exp_font = 7'b1111101;
            4'd7:    exp_font = 7'b0000111;
            4'd8:    exp_font = 7'b1111111;
            4'd9:    exp_font = 7'b1101111;
            4'd10:   exp_font = 7'b1011100;  // lower o
            4'd11:   exp_font = 7'b1100011;  // raised o
            4'd12:   exp_font = 7'b0000001;  // top bar
            4'd13:   exp_font = 7'b1000000;  // middle bar
            4'd14:   exp_font = 7'b0001000;  // bottom bar
            default: exp_font = 7'b0000000;  // blank
        endcase
    endfunction

    logic [3:0] code [6] = '{4'd1, 4'd8, 4'd6, 4'd5, 4'd3, 4'd15};
    int pd, pt;

    task tick;
        begin
            osc = 1; #1;
            osc = 0; #1;
        end
    endtask

    task step;  // one scan tick, tracking the phase model
        begin
            if (pt == CPD) begin
                pt = 0;
                pd = (pd + 1) % 6;
            end else begin
                pt = pt + 1;
            end
            tick();
        end
    endtask

    task check_active(input int dg);
        begin
            assert (digit === (6'b000001 << dg)) else $fatal(1, "digit one-hot %0d: got %b", dg, digit);
            assert (seg === exp_font(code[dg])) else $fatal(1, "seg digit %0d code %0d: got %b", dg, code[dg], seg);
        end
    endtask

    task check_blank;
        begin
            assert (digit === 6'b000000 && seg === 7'b0000000)
                else $fatal(1, "blank slot outputs: %b %b", digit, seg);
        end
    endtask

    int i, t;
    initial begin
        osc = 0; ce_n = 1; we_n = 1; d = 4'h0; k = 3'd0;
        pd = 0; pt = 0;
        #1;

        // Write six registers (transparent while CE and WE low, latched when
        // either returns high); null addresses 6 and 7 write nothing.
        for (i = 0; i < 6; i++) begin
            k = i[2:0]; ce_n = 0; we_n = 0;
            d = code[i]; #1;
            d = ~code[i]; #1;                   // transparent follow
            d = code[i]; #1;
            we_n = 1; d = 4'hxF; #1;            // latched
            ce_n = 1; we_n = 0; d = 4'hxA; #1;  // disabled
            we_n = 1; #1;
        end
        for (i = 6; i < 8; i++) begin
            k = i[2:0]; ce_n = 0; we_n = 0; d = 4'd8; #1;
            we_n = 1; ce_n = 1; #1;
        end

        // Refresh: D1..D6 ascending with one blank tick between slots, always
        // running (the 913 has no oscillator-enable or output-enable pins).
        for (t = 0; t < 2 * 6 * (CPD + 1); t++) begin
            step();
            if (pt == CPD) check_blank();
            else check_active(pd);
        end

        // Full font sweep: rewrite digit 1 and watch its next active slot.
        for (i = 0; i < 16; i++) begin
            k = 3'd0; ce_n = 0; we_n = 0; d = i[3:0]; #1;
            we_n = 1; ce_n = 1; d = 4'h0; #1;
            for (t = 0; t < 6 * (CPD + 1); t++) begin
                step();
                if (pt != CPD && pd == 0) begin
                    assert (digit === 6'b000001 && seg === exp_font(i[3:0]))
                        else $fatal(1, "font code %0d: got %b", i, seg);
                    break;
                end
            end
            assert (pt != CPD && pd == 0) else $fatal(1, "digit 1 slot not reached");
        end
        // Register 0 now holds code 15 (blank font): segment data zero while
        // the digit line still strobes.
        k = 3'd0; ce_n = 0; we_n = 0; d = 4'd9; #1;
        we_n = 1; ce_n = 1; d = 4'h0; #1;

        $display("PASS: tb_ttl_74x913");
        $finish;
    end
endmodule
