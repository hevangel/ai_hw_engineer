module tb_ttl_74x923;
    logic       osc, oe_n, da, data_drive;
    logic [4:0] row, data;
    logic [3:0] col_n;

    ttl_74x923 dut(.*);

    // 4x5 switch matrix: bit 4*r+c closed pulls row r low while column c is
    // the driven (low) column; rows float high otherwise (pull-ups).
    logic [19:0] keys;
    always_comb begin
        row = 5'b11111;
        for (int r = 0; r < 5; r++)
            for (int c = 0; c < 4; c++)
                if (keys[4*r+c] && !col_n[c]) row[r] = 1'b0;
    end

    // Defeated-debounce variant (no KBM capacitor).
    logic       osc0, oe_n0, da0, data_drive0;
    logic [4:0] row0, data0;
    logic [3:0] col_n0;
    logic [19:0] keys0;
    ttl_74x923 #(.DEBOUNCE_CYCLES(0)) dut0 (
        .osc(osc0), .row(row0), .col_n(col_n0), .oe_n(oe_n0),
        .data(data0), .data_drive(data_drive0), .da(da0)
    );
    always_comb begin
        row0 = 5'b11111;
        for (int r = 0; r < 5; r++)
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

    function automatic logic [4:0] keycode(input int r, input int c);
        keycode = {r[2], r[1], r[0], c[1], c[0]};
    endfunction

    int r, c, t;
    initial begin
        osc = 0; osc0 = 0; oe_n = 0; oe_n0 = 0; keys = 20'h00000; keys0 = 20'h00000;
        #1;

        // Scan order: X1,X2,X3,X4 ascending, exactly one column low. The
        // counter starts on X1 and advances on each rising edge, so after
        // tick t the driven column is (t+1) mod 4. After eight ticks the
        // scan counter is back on X1.
        assert (col_n === 4'b1110) else $fatal(1, "initial column not X1: got %b", col_n);
        for (t = 0; t < 8; t++) begin
            tick();
            assert (col_n === ~(4'b0001 << ((t + 1) % 4)))
                else $fatal(1, "scan order tick %0d: got %b", t, col_n);
            assert ($onehot(~col_n)) else $fatal(1, "multiple columns driven");
        end

        // Entry with debounce timing: key (r4,c1) needs DEBOUNCE_CYCLES=2
        // visits of X2; with the scan on X1 the DA rise lands on tick 7.
        keys[4*4+1] = 1'b1;
        for (t = 1; t <= 6; t++) begin
            tick();
            assert (da === 1'b0) else $fatal(1, "DA early at tick %0d", t);
        end
        tick();
        assert (da === 1'b1) else $fatal(1, "DA not set after debounce");
        assert (data === keycode(4, 1)) else $fatal(1, "E-row code: got %b", data);
        keys[4*4+1] = 1'b0;
        for (t = 0; t < 8 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "DA did not fall on release");
        assert (data === keycode(4, 1)) else $fatal(1, "last-key register lost");

        // All twenty switch positions with their truth-table codes. A key is
        // debounced, entered, released; DA falls on release and the register
        // retains the code.
        for (r = 0; r < 5; r++) begin
            for (c = 0; c < 4; c++) begin
                keys[4*r+c] = 1'b1;
                for (t = 0; t < 12 && da === 1'b0; t++) tick();
                assert (da === 1'b1) else $fatal(1, "entry key (%0d,%0d)", r, c);
                assert (data === keycode(r, c) && data_drive === 1'b1)
                    else $fatal(1, "code key (%0d,%0d): got %b", r, c, data);
                keys[4*r+c] = 1'b0;
                for (t = 0; t < 8 && da === 1'b1; t++) tick();
                assert (da === 1'b0) else $fatal(1, "release key (%0d,%0d)", r, c);
                assert (data === keycode(r, c)) else $fatal(1, "register key (%0d,%0d)", r, c);
                tick();
            end
        end

        // Two-key rollover onto the fifth row.
        keys[4*0+0] = 1'b1;                       // K1 = (r0,c0)
        for (t = 0; t < 12 && da === 1'b0; t++) tick();
        assert (da === 1'b1 && data === keycode(0, 0)) else $fatal(1, "K1 entry");
        keys[4*4+3] = 1'b1;                       // K2 = (r4,c3)
        for (t = 0; t < 10; t++) tick();
        assert (da === 1'b1 && data === keycode(0, 0))
            else $fatal(1, "K2 accepted while K1 still entered");
        keys[4*0+0] = 1'b0;
        for (t = 0; t < 8 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "DA did not fall when K1 released");
        for (t = 0; t < 8 && da === 1'b0; t++) tick();
        assert (da === 1'b1 && data === keycode(4, 3)) else $fatal(1, "rollover K2 entry");
        keys[4*4+3] = 1'b0;
        for (t = 0; t < 8 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "final rollover release");

        // Output Enable gates only the data outputs; DA is unaffected.
        oe_n = 1;
        keys[4*2+2] = 1'b1;
        for (t = 0; t < 12 && da === 1'b0; t++) tick();
        assert (da === 1'b1) else $fatal(1, "entry with OE disabled");
        assert (data === 5'b00000 && data_drive === 1'b0)
            else $fatal(1, "disabled outputs must be zero");
        oe_n = 0; #1;
        assert (data === keycode(2, 2) && data_drive === 1'b1)
            else $fatal(1, "OE re-enable shows register");
        keys[4*2+2] = 1'b0;
        for (t = 0; t < 8 && da === 1'b1; t++) tick();
        assert (da === 1'b0) else $fatal(1, "OE section release");

        // Defeated debounce (KBM capacitor omitted): accepted on the first
        // visit of the key's column.
        keys0[4*3+2] = 1'b1;
        for (t = 0; t < 6 && da0 === 1'b0; t++) tick0();
        assert (da0 === 1'b1 && data0 === keycode(3, 2) && data_drive0 === 1'b1)
            else $fatal(1, "defeated debounce entry: da=%b data=%b", da0, data0);

        $display("PASS: tb_ttl_74x923");
        $finish;
    end
endmodule
