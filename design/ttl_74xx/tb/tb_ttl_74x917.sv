module tb_ttl_74x917;
    localparam int CPD = 4;  // CYCLES_PER_DIGIT default
    logic osc, ce_n, we_n, ose_n, soe_n;
    logic [3:0] d;
    logic       dp;
    logic [2:0] k;
    logic [5:0] digit;
    logic       digit_drive;
    logic [6:0] seg;
    logic       seg_dp, seg_drive;

    ttl_74x917 dut(.*);

    // Expected hex font, {g,f,e,d,c,b,a}, from the datasheet character font
    // table (MM74C917 row): 0-9 then A,b,C,d,E,F.
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
            4'd10:   exp_font = 7'b1110111;  // A
            4'd11:   exp_font = 7'b1111100;  // b
            4'd12:   exp_font = 7'b0111001;  // C
            4'd13:   exp_font = 7'b1011110;  // d
            4'd14:   exp_font = 7'b1111001;  // E
            default: exp_font = 7'b1110001;  // F
        endcase
    endfunction

    logic [3:0] code [6] = '{4'd10, 4'd12, 4'd14, 4'd15, 4'd11, 4'd13};
    logic       dpbit [6] = '{1'b1, 1'b0, 1'b1, 1'b0, 1'b1, 1'b0};
    int pd, pt;

    task tick;
        begin
            osc = 1; #1;
            osc = 0; #1;
        end
    endtask

    task step;  // one scan tick while ose_n = 0, tracking the phase model
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
            assert (seg_dp === dpbit[dg]) else $fatal(1, "seg_dp digit %0d", dg);
            assert (seg_drive === 1'b1 && digit_drive === 1'b1) else $fatal(1, "drives in refresh");
        end
    endtask

    task check_blank;
        begin
            assert (digit === 6'b000000) else $fatal(1, "blank digits: got %b", digit);
            assert (seg === 7'b0000000 && seg_dp === 1'b0 && seg_drive === 1'b0)
                else $fatal(1, "blank slot outputs");
        end
    endtask

    int i, t;
    initial begin
        osc = 0; ce_n = 1; we_n = 1; ose_n = 0; soe_n = 0;
        d = 4'h0; dp = 0; k = 3'd0;
        pd = 0; pt = 0;
        #1;

        // Write six registers with distinct hex codes; null address 7 must
        // not disturb anything.
        for (i = 0; i < 6; i++) begin
            k = i[2:0]; ce_n = 0; we_n = 0;
            d = code[i]; dp = dpbit[i]; #1;
            d = ~code[i]; #1;                       // transparent follow
            d = code[i]; dp = dpbit[i]; #1;
            we_n = 1; d = 4'hxF; dp = 1'b0; #1;     // latched
            ce_n = 1; we_n = 0; d = 4'hxA; dp = 1'b1; #1;  // disabled
            we_n = 1; #1;
        end
        k = 3'd7; ce_n = 0; we_n = 0; d = 4'd8; dp = 1'b1; #1;
        we_n = 1; ce_n = 1; #1;

        // Refresh: D1..D6 ascending with one blank tick between slots.
        for (t = 0; t < 2 * 6 * (CPD + 1); t++) begin
            step();
            if (pt == CPD) check_blank();
            else check_active(pd);
        end

        // Freeze the scanner on digit 1 and sweep all sixteen hex codes with
        // the decimal-point bypass; check the null-address no-op.
        for (t = 0; t < 6 * (CPD + 1); t++) begin
            #1;
            if (digit === 6'b000001) begin
                ose_n = 1;
                break;
            end
            step();
        end
        assert (ose_n === 1'b1 && digit === 6'b000001) else $fatal(1, "failed to freeze on D1");
        for (t = 0; t < 3; t++) begin
            tick();
            assert (digit === 6'b000001) else $fatal(1, "OSE high must stop the scan");
        end
        for (i = 0; i < 16; i++) begin
            k = 3'd0; ce_n = 0; we_n = 0; d = i[3:0]; dp = 1'b0; #1;
            assert (seg === exp_font(i[3:0]) && seg_drive === 1'b1 && seg_dp === 1'b0)
                else $fatal(1, "hex font code %0d: got %b", i, seg);
            dp = 1'b1; #1;
            assert (seg === exp_font(i[3:0]) && seg_dp === 1'b1)
                else $fatal(1, "dp bypass at code %0d", i);
            dp = 1'b0; we_n = 1; ce_n = 1; #1;
        end
        k = 3'd0; ce_n = 0; we_n = 0; d = 4'd0; dp = 1'b0; #1;
        we_n = 1; ce_n = 1; #1;
        code[0] = 4'd0; dpbit[0] = 1'b0;      // TB model mirrors register 0
        k = 3'd7; ce_n = 0; we_n = 0; d = 4'd5; dp = 1'b1; #1;
        assert (seg === exp_font(4'd0) && seg_dp === 1'b0)
            else $fatal(1, "null address write changed the display");
        we_n = 1; ce_n = 1; #1;

        // SOE gates the frozen display; oscillator stays stopped.
        soe_n = 1; #1;
        assert (seg === 7'b0000000 && seg_dp === 1'b0 && seg_drive === 1'b0)
            else $fatal(1, "SOE disable frozen display");
        soe_n = 0; #1;
        assert (seg === exp_font(4'd0)) else $fatal(1, "SOE re-enable frozen display");
        ose_n = 0; #1;

        // Standby: oscillator stopped and segments disabled together.
        ose_n = 1; soe_n = 1; #1;
        for (t = 0; t < 4; t++) begin
            tick();
            assert (seg === 7'b0000000 && seg_drive === 1'b0 && seg_dp === 1'b0)
                else $fatal(1, "standby segment outputs");
        end
        ose_n = 0; soe_n = 0; #1;

        // Write while refreshing: digit 5 rewritten to F, visible next slot.
        k = 3'd5; ce_n = 0; we_n = 0; d = 4'd15; dp = 1'b0; #1;
        we_n = 1; ce_n = 1; d = 4'h0; #1;
        for (t = 0; t < 6 * (CPD + 1); t++) begin
            step();
            if (pt == CPD) check_blank();
            else if (pd == 5) begin
                assert (seg === exp_font(4'd15) && seg_dp === 1'b0)
                    else $fatal(1, "write during refresh digit 5");
            end else check_active(pd);
        end

        $display("PASS: tb_ttl_74x917");
        $finish;
    end
endmodule
