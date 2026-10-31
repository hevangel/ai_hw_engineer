module tb_ttl_74x911;
    localparam int CPD = 4;  // CYCLES_PER_DIGIT default
    logic osc, ce_n, we_n, soe_n, dio_n;
    logic [7:0] d_in;
    logic [1:0] k;
    logic [3:0] digit_in, digit;
    logic       digit_drive;
    logic [7:0] seg;
    logic       seg_drive;

    ttl_74x911 dut(.*);

    // Distinct display patterns; registers end holding ~PAT.
    logic [7:0] PAT [4] = '{8'h0F, 8'h36, 8'hC3, 8'h5A};
    int pd, pt;  // TB model of the scanner phase (digit, tick)

    task tick;
        begin
            osc = 1; #1;
            osc = 0; #1;
        end
    endtask

    task step;  // one scan tick while dio_n = 0, tracking the phase model
        begin
            if (pt == CPD) begin
                pt = 0;
                pd = (pd + 1) % 4;
            end else begin
                pt = pt + 1;
            end
            tick();
        end
    endtask

    task check_active(input int d);
        begin
            assert (digit === (4'b0001 << d)) else $fatal(1, "digit one-hot %0d: got %b", d, digit);
            assert (seg === ~PAT[d]) else $fatal(1, "seg of digit %0d: got %b", d, seg);
            assert (seg_drive === 1'b1) else $fatal(1, "seg_drive active digit %0d", d);
            assert (digit_drive === 1'b1) else $fatal(1, "digit_drive in refresh");
        end
    endtask

    task check_blank;
        begin
            assert (digit === 4'b0000) else $fatal(1, "blank digit lines: got %b", digit);
            assert (seg === 8'h00) else $fatal(1, "blank segments: got %b", seg);
            assert (seg_drive === 1'b0) else $fatal(1, "blank seg_drive");
        end
    endtask

    int i, t, saved_d;
    initial begin
        osc = 0; ce_n = 1; we_n = 1; soe_n = 0; dio_n = 1;
        d_in = 8'h00; k = 2'd0; digit_in = 4'b0000;
        pd = 0; pt = 0;
        #1;

        // Slave-mode writes: transparent while CE and WE low, latched when WE
        // or CE returns high, ignored with CE high (input control table).
        for (i = 0; i < 4; i++) begin
            k = i[1:0];
            digit_in = 4'b0001 << i;
            ce_n = 0; we_n = 0; d_in = PAT[i]; #1;
            assert (seg === PAT[i]) else $fatal(1, "transparent write digit %0d", i);
            d_in = ~PAT[i]; #1;
            assert (seg === ~PAT[i]) else $fatal(1, "transparent follow digit %0d", i);
            we_n = 1; #1;
            assert (seg === ~PAT[i]) else $fatal(1, "latch on WE rise digit %0d", i);
            d_in = PAT[i]; #1;
            assert (seg === ~PAT[i]) else $fatal(1, "data change with WE high digit %0d", i);
            ce_n = 1; we_n = 0; d_in = 8'hA5; #1;
            assert (seg === ~PAT[i]) else $fatal(1, "CE high disables writing digit %0d", i);
            we_n = 1; d_in = 8'h00; #1;
        end

        // Refresh: D1..D4 ascending with one blank tick between slots.
        dio_n = 0; digit_in = 4'b0000;
        #1;
        check_active(0);  // phase starts at digit 1 slot tick 0
        for (t = 0; t < 2 * 4 * (CPD + 1); t++) begin
            step();
            if (pt == CPD) check_blank();
            else check_active(pd);
        end

        // Segment disable: scan continues, segments off (SOE high).
        soe_n = 1;
        for (t = 0; t < 8; t++) begin
            step();
            assert (seg === 8'h00 && seg_drive === 1'b0)
                else $fatal(1, "SOE disable segments");
            if (pt == CPD) begin
                assert (digit === 4'b0000) else $fatal(1, "SOE blank digit");
            end else begin
                assert (digit === (4'b0001 << pd)) else $fatal(1, "SOE scan continues");
            end
        end
        soe_n = 0; #1;
        check_active(pd);

        // Slave mode halts the scanner and preserves its phase.
        saved_d = pd;
        dio_n = 1; #1;
        assert (digit === 4'b0000 && digit_drive === 1'b0)
            else $fatal(1, "slave mode digit lines are inputs");
        for (t = 0; t < 10; t++) tick();
        digit_in = 4'b0001 << saved_d; #1;
        assert (seg === ~PAT[saved_d] && seg_drive === 1'b1)
            else $fatal(1, "slave displays selected digit");
        dio_n = 0; #1;
        assert (digit === 4'b0001 << saved_d) else $fatal(1, "phase not preserved");
        for (t = 0; t < 4 * (CPD + 1); t++) begin
            step();
            if (pt == CPD) check_blank();
            else check_active(pd);
        end

        // Write while refreshing: digit 3 rewritten, visible on its next slot.
        k = 2'd3; ce_n = 0; we_n = 0; d_in = 8'h81; #1;
        we_n = 1; ce_n = 1; d_in = 8'h00; #1;
        for (t = 0; t < 4 * (CPD + 1); t++) begin
            step();
            if (pt == CPD) check_blank();
            else begin
                if (pd == 3) begin
                    assert (seg === 8'h81) else $fatal(1, "write during refresh digit 3");
                end else check_active(pd);
            end
        end

        // Digits-are-inputs (no digit selected) and power-saver output states.
        dio_n = 1; digit_in = 4'b0000; #1;
        assert (seg === 8'h00 && seg_drive === 1'b0)
            else $fatal(1, "no digit selected releases segments");
        soe_n = 1; #1;
        assert (seg === 8'h00 && seg_drive === 1'b0 && digit_drive === 1'b0)
            else $fatal(1, "power saver outputs off");
        digit_in = 4'b0100; #1;
        assert (seg_drive === 1'b0) else $fatal(1, "SOE gates slave display");

        $display("PASS: tb_ttl_74x911");
        $finish;
    end
endmodule
