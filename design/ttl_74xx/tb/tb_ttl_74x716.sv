`timescale 1ns/1ps
module tb_ttl_74x716;
    logic clock, gate, mr_n, pe_n, external_bus_low;
    logic [3:0] preset, q;
    logic bus;

    ttl_74x716 dut (.*);

    task automatic tick;
        begin
            clock = 1'b1;
            #1;
            clock = 1'b0;
            #1;
        end
    endtask

    task automatic check_q(input logic [3:0] expected);
        begin
            if (q !== expected)
                $fatal(1, "74x716 count mismatch: got %x expected %x", q, expected);
        end
    endtask

    function automatic logic [3:0] reference_preset(input logic [3:0] value);
        reference_preset = (value > 4'd9) ? {1'b0, value[2:0]} : value;
    endfunction

    initial begin
        clock = 1'b0;
        gate = 1'b1;
        mr_n = 1'b1;
        pe_n = 1'b1;
        preset = 4'd0;
        external_bus_low = 1'b0;
        #1;
        // Motorola documents entering zero with both MR and PE asserted.
        mr_n = 1'b0;
        pe_n = 1'b0;
        #1;
        check_q(4'd0);
        if (bus !== 1'b1) $fatal(1, "Bus must be high at zero with pull-up");
        mr_n = 1'b1;
        pe_n = 1'b1;
        #1;

        // All 16 data combinations: hold preset stable through the PE-low
        // asynchronous load pulse; >9 ignore P8 for this decade device.
        for (int value = 0; value < 16; value++) begin
            preset = 4'(value);
            pe_n = 1'b0;
            #1;
            check_q(reference_preset(4'(value)));
            pe_n = 1'b1;
            #1;
            if (preset != 4'(value)) $fatal(1, "test stimulus changed unexpectedly");

            // A complete decimal cycle exercises every output row and natural wrap.
            for (int step = 0; step < 10; step++) begin
                logic [3:0] expected;
                expected = reference_preset(4'(value));
                for (int prior = 0; prior < step; prior++) begin
                    expected = (expected == 4'd0) ? 4'd9 : expected - 4'd1;
                end
                check_q(expected);
                if (bus !== (expected == 4'd0))
                    $fatal(1, "Bus terminal level mismatch at %x", expected);
                tick();
            end
        end

        // Terminal zero holds Bus high until Gate returns low, then reloads P.
        preset = 4'd7;
        pe_n = 1'b0;
        #1;
        check_q(4'd7);
        pe_n = 1'b1;
        #1;
        for (int step = 0; step < 7; step++) tick();
        check_q(4'd0);
        if (bus !== 1'b1) $fatal(1, "Bus pulse must rise at terminal zero");
        gate = 1'b0;
        #1;
        check_q(4'd7);
        if (bus !== 1'b0) $fatal(1, "automatic reload must return Bus low");

        // A low shared Bus inhibits reload; release of the wired Bus permits it.
        gate = 1'b1;
        preset = 4'd5;
        pe_n = 1'b0;
        #1;
        pe_n = 1'b1;
        #1;
        for (int step = 0; step < 5; step++) tick();
        check_q(4'd0);
        external_bus_low = 1'b1;
        gate = 1'b0;
        #1;
        check_q(4'd0);
        if (bus !== 1'b0) $fatal(1, "external low must dominate the shared Bus");
        external_bus_low = 1'b0;
        #1;
        check_q(4'd5);

        // Master reset is asynchronous and overrides all other controls.
        mr_n = 1'b0;
        #1;
        check_q(4'd0);
        mr_n = 1'b1;
        gate = 1'b1;
        #1;
        check_q(4'd0);

        $display("PASS: tb_ttl_74x716");
        $finish;
    end
endmodule
