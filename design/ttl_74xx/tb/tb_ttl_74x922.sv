module tb_ttl_74x922;
    logic       osc, oe_n, da, data_drive;
    logic [3:0] row, col_n, data;

    ttl_74x922 dut(.*);

    // 4x4 switch matrix: bit 4*r+c closed pulls row r low while column c is
    // the driven (low) column; rows float high otherwise (pull-ups).
    logic [15:0] keys;
    always_comb begin
        row = 4'b1111;
        for (int r = 0; r < 4; r++)
            for (int c = 0; c < 4; c++)
                if (keys[4*r+c] && !col_n[c]) row[r] = 1'b0;
    end

    // Defeated-debounce variant (no KBM capacitor).
    logic       osc0, oe_n0, da0, data_drive0;
    logic [3:0] row0, col_n0, data0;
    logic [15:0] keys0;
    ttl_74x922 #(.DEBOUNCE_CYCLES(0)) dut0 (
        .osc(osc0), .row(row0), .col_n(col_n0), .oe_n(oe_n0),
        .data(data0), .data_drive(data_drive0), .da(da0)
    );
    always_comb begin
        row0 = 4'b1111;
        for (int r = 0; r < 4; r++)
            for (int c = 0; c < 4; c++)
                if (keys0[4*r+c] && !col_n0[c]) row0[r] = 1'b0;
    end

    task tick;
        begin
            osc = 1; #1;
            osc = 0; #1;
        end
    endtask

    task tick0;
        begin
            osc0 = 1; #1;
            osc0 = 0; #1;
        end
    endtask

    function automatic logic [3:0] keycode(input int r, input int c);
        keycode = {r[1], r[0], c[1], c[0]};
    endfunction

    int t;
    initial begin
        osc = 0; osc0 = 0; oe_n = 0; oe_n0 = 0; keys = 16'h0000; keys0 = 16'h0000;
        #1;

        // Scan order: X1,X2,X3,X4 ascending, exactly one column low. The
        // counter starts on X1 and advances on each rising edge, so after
        // tick t the driven column is (t+1) mod 4.
        assert (col_n === 4'b1110) else $fatal(1, "initial column not X1: got %b", col_n);
        for (t = 0; t < 8; t++) begin
            tick();
            assert (col_n === ~(4'b0001 << ((t + 1) % 4)))
                else $fatal(1, "scan order tick %0d: got %b", t, col_n);
            assert ($onehot(~col_n)) else $fatal(1, "multiple columns driven");
        end

        // Entry with debounce: key (r2,c1) needs DEBOUNCE_CYCLES=2 visits of
        // column X2; with the scan starting at X1, DA rises after 7 ticks.
        keys[4*2+1] = 1'b1;
        for (t = 1; t <= 6; t++) begin
            tick();
            assert (da === 1'b0) else $fatal(1, "DA early at tick %0d", t);
        end
        tick();
        assert (da === 1'b1) else $fatal(1, "DA not set after debounce");
        assert (data === keycode(2, 1) && data_drive === 1'b1)
            else $fatal(1, "key code: got %b", data);

        // Hold: DA stays high while the entered key stays closed.
        for (t = 0; t < 6; t++) begin
            tick();
            assert (da === 1'b1 && data === keycode(2, 1)) else $fatal(1, "hold lost");
        end

        // Release: DA falls at the next visit of the entered column; the
        // last-key register keeps the code.
        keys[4*2+1] = 1'b0;
        for (t = 0; t < 6 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "DA did not fall on release");
        assert (data === keycode(2, 1)) else $fatal(1, "last-key register lost");
        for (t = 0; t < 6; t++) begin
            tick();
            assert (da === 1'b0) else $fatal(1, "DA rose without a key");
            assert (data === keycode(2, 1)) else $fatal(1, "register not retained");
        end

        // Two-key rollover: K1 entered; K2 debounced while K1 holds; DA falls
        // when K1 releases and rises again with K2's code.
        keys[4*0+0] = 1'b1;                       // K1 = (r0,c0), code 0000
        for (t = 0; t < 12 && da === 1'b0; t++) tick();
        assert (da === 1'b1 && data === keycode(0, 0)) else $fatal(1, "K1 entry");
        keys[4*2+3] = 1'b1;                       // K2 = (r2,c3), code 1011
        for (t = 0; t < 10; t++) tick();
        assert (da === 1'b1 && data === keycode(0, 0))
            else $fatal(1, "K2 accepted while K1 still entered");
        keys[4*0+0] = 1'b0;                       // release K1
        for (t = 0; t < 8 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "DA did not fall when K1 released");
        for (t = 0; t < 8 && da === 1'b0; t++) tick();
        assert (da === 1'b1 && data === keycode(2, 3)) else $fatal(1, "rollover K2 entry");
        keys[4*2+3] = 1'b0;
        for (t = 0; t < 8 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "DA did not fall when K2 released");

        // Debounce abort: less than DEBOUNCE_CYCLES visits then release.
        keys[4*3+2] = 1'b1;
        for (t = 0; t < 4; t++) tick();           // at most one visit per column
        keys[4*3+2] = 1'b0;
        for (t = 0; t < 8; t++) begin
            tick();
            assert (da === 1'b0) else $fatal(1, "bounce abort accepted");
        end

        // Output Enable gates only the data outputs.
        oe_n = 1;
        keys[4*1+1] = 1'b1;
        for (t = 0; t < 12 && da === 1'b0; t++) tick();
        assert (da === 1'b1) else $fatal(1, "entry with OE disabled");
        assert (data === 4'b0000 && data_drive === 1'b0)
            else $fatal(1, "disabled outputs must be zero");
        oe_n = 0; #1;
        assert (data === keycode(1, 1) && data_drive === 1'b1)
            else $fatal(1, "OE re-enable shows register");
        keys[4*1+1] = 1'b0;
        for (t = 0; t < 8 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "cleanup release");

        // Two keys on one column: the lowest-numbered row is detected.
        keys[4*0+1] = 1'b1;
        keys[4*1+1] = 1'b1;
        for (t = 0; t < 12 && da === 1'b0; t++) tick();
        assert (da === 1'b1 && data === keycode(0, 1))
            else $fatal(1, "same-column lowest row: got %b", data);
        keys = 16'h0000;
        for (t = 0; t < 8 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "final cleanup release");

        // Defeated debounce (KBM capacitor omitted): accepted on the first
        // visit of the key's column.
        keys0[4*1+2] = 1'b1;
        for (t = 0; t < 6 && da0 === 1'b0; t++) tick0();
        assert (da0 === 1'b1 && data0 === keycode(1, 2) && data_drive0 === 1'b1)
            else $fatal(1, "defeated debounce entry: da=%b data=%b", da0, data0);

        $display("PASS: tb_ttl_74x922");
        $finish;
    end
endmodule
