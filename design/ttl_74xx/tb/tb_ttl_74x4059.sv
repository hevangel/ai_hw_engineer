`timescale 1ns/1ps

module tb_ttl_74x4059;
    logic cp;
    logic le;
    logic [2:0] k;
    logic [15:0] j;
    logic q;

    ttl_74x4059 dut (
        .cp(cp),
        .le(le),
        .k(k),
        .j(j),
        .q(q)
    );

    task automatic tick;
        begin
            cp = 1'b0;
            #1;
            cp = 1'b1;
            #1;
        end
    endtask

    task automatic enter_master_preset(input logic [15:0] jam_value);
        begin
            cp = 1'b0;
            le = 1'b0;
            k = 3'b000; // Kb=Kc=0; Ka is a don't-care in master preset.
            j = jam_value;
            repeat (4) tick(); // Datasheet requires at least three full clocks.
            if (q !== 1'b0) begin
                $fatal(1, "Q must be low during master preset");
            end
        end
    endtask

    task automatic check_divide(
        input logic [2:0] mode,
        input logic [15:0] jam_value,
        input integer expected_n
    );
        integer cycle;
        begin
            enter_master_preset(jam_value);
            k = mode;
            tick(); // First edge after MP loads the mode-specific jam layout.
            if (q !== 1'b0) begin
                $fatal(1, "Q asserted on the mode-transfer edge, mode=%b", mode);
            end

            // The source specifies one extra start clock after master preset;
            // the following expected_n counted edges must end at the first Q.
            for (cycle = 1; cycle <= expected_n; cycle = cycle + 1) begin
                tick();
                if (q !== (cycle == expected_n)) begin
                    $fatal(1,
                        "first period mismatch mode=%b cycle=%0d N=%0d Q=%b",
                        mode, cycle, expected_n, q);
                end
            end

            // The no-latch output must be one CP wide, and reload must produce
            // exactly N clocks between subsequent pulses.
            for (cycle = 1; cycle <= expected_n; cycle = cycle + 1) begin
                tick();
                if (q !== (cycle == expected_n)) begin
                    $fatal(1,
                        "repeated period mismatch mode=%b cycle=%0d N=%0d Q=%b",
                        mode, cycle, expected_n, q);
                end
            end
        end
    endtask

    task automatic check_latch_enable;
        integer cycle;
        begin
            enter_master_preset(16'h0011); // ÷2, R=1, quotient=1 => N=3.
            le = 1'b1;
            k = 3'b111;
            tick();
            for (cycle = 1; cycle <= 3; cycle = cycle + 1) begin
                tick();
                if (q !== (cycle == 3)) begin
                    $fatal(1, "LE test pulse mismatch at cycle %0d", cycle);
                end
            end
            repeat (4) begin
                tick();
                if (q !== 1'b1) begin
                    $fatal(1, "LE did not hold Q high between output pulses");
                end
            end
            le = 1'b0;
            #1; // No CP edge: LE-to-Q release must be asynchronous.
            if (q !== 1'b0) begin
                $fatal(1, "Q did not release asynchronously when LE returned low");
            end
            tick();
            if (q !== 1'b0) begin
                $fatal(1, "Q reasserted after LE release without a terminal count");
            end
        end
    endtask

    initial begin
        cp = 1'b0;
        le = 1'b0;
        k = 3'b000;
        j = 16'h0000;

        // J1-J4 split: J1 is R=1, J2 encodes L=1; N=2*1000+1.
        check_divide(3'b111, 16'h0003, 2001);
        // Extended ÷2 limit: L=7, all middle digits=15, R=1.
        check_divide(3'b111, 16'hffff, 17331);

        // ÷4 split: J1-J2 encode R=3, J3 encodes L=1; J5 encodes D1=1.
        // N=4*(1000+1)+3=4007.
        check_divide(3'b011, 16'h0017, 4007);
        // Extended ÷4 limit: L=3, all middle digits=15, R=3.
        check_divide(3'b011, 16'hffff, 18663);

        // TI's printed example: ÷5, L=1, D100=6, D10=9, D1=5, R=4.
        check_divide(3'b101, 16'h695c, 8479);
        // Extended ÷5 limit: L=1, all middle digits=15, R=4.
        check_divide(3'b101, 16'hfffc, 13329);

        // Figure 1's ÷8 count of 3 is represented by R=3 and quotient=0.
        check_divide(3'b001, 16'h0003, 3);
        // A zero remainder starts with a full first-section interval: N=8.
        check_divide(3'b001, 16'h0010, 8);

        // TI's extended ÷8 maximum example: L=1, all digits=15, R=7.
        check_divide(3'b001, 16'hffff, 21327);

        // Extended ÷10 maximum from the TI range table: digits=15, R=9.
        check_divide(3'b110, 16'hfff9, 16659);

        check_latch_enable();

        $display("PASS: tb_ttl_74x4059 (mode splits, BCD weighting, extended presets, pulse and LE)");
        $finish;
    end
endmodule
